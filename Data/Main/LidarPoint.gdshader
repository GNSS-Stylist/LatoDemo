shader_type spatial;

//render_mode cull_disabled, depth_draw_always;
render_mode unshaded, blend_add;
//render_mode unshaded, blend_mix, depth_draw_always;

// ReplayTime is divided into two parts to get more resolution.
// For "super slo-mo" float is not enough so remainder is used to
// "fine tune" the locally calculated replay time difference.
uniform float replayTime;
uniform float replayTimeRemainder;

uniform float outOfSightShift_Y = 10.0;

uniform float fadeoutStartPointSize = 1.0;
uniform float fadeoutStartTime = 0.0;

uniform float fadeoutEndPointSize = 0.0;
uniform float fadeoutEndTime = 5000.0;
uniform float fadeoutEndAlpha = 0.5;

uniform float disappearanceTime = 5000.0;

uniform int pointSkip = 0;

uniform int antiAlias = 8;

// To prevent flying points from being drawn inside the lidar
// (Points' start position is shifted this amount towards the hit point)
uniform float flyStartOriginShift = 0.03;

uniform float flySpeed = 100.0;			// m/s
uniform float flyStartTime = 0.0;
uniform float maxFlyEndTime = 200.0;	// ms
uniform vec4 flyStartAlbedo : source_color;
uniform float flyStartPointSize = 5.0;
uniform vec4 flyEndAlbedo : source_color;
uniform float flyEndPointSize = 5.0;

uniform float hitAlbedoAttackHighTime = 1.0;
uniform float hitAlbedoAttackFadeoutTime = 2.0;
uniform vec4 hitAlbedoAttackColor : source_color;
uniform float hitAlbedoAttackPointSize = 10.0;


// Indexes here are of type LSItemType from LidarDataStorage.gd
// If alpha == 0, no point is drawn
uniform vec4 pointColors[16] : source_color;

//uniform float mysticMultiplier = 1;

uniform float timeMultiplier = 1.0;

//uniform vec4 pointOkColor : hint_color = vec4(0.0, 1.0, 0.0, 1.0);
//uniform vec4 pointOkColor : hint_color = vec4(0.0, 1.0, 0.0, 1.0);

varying flat float discardFragment;	// This is bool...
varying flat vec3 fragmentAlbedo;
varying flat float fragmentAlpha;

void vertex() {
	float timeDiff = (replayTime - UV2.x) * timeMultiplier;	// UV2.x = shotTime
	timeDiff += replayTimeRemainder;
	int pointColorIndex = int(UV2.y + 0.5) & 0x0F;
	float pointAlpha = pointColors[pointColorIndex].a;
	int pointIndex = int(CUSTOM0.a);
	
	if ((timeDiff < 0.0) || (timeDiff >= disappearanceTime) || (pointAlpha == 0.0) || 
			(pointSkip == 0) || (pointIndex % pointSkip != 0))
	{
		// Face not visible -> Throw it out of sight
		VERTEX.y += outOfSightShift_Y;
		discardFragment = 1.0;
//		VERTEX.y += 10.0;
	}
	else
	{
		discardFragment = 0.0;
//		vec3 pointColor = pointColors[int(UV2.y) & 0xF].xyz;
//		COLOR = pointColors[int(UV2.y) & 0xF];
	
		vec3 currentOrigin = CUSTOM0.xyz;
		float pointSize;
		float flyDistance = (timeDiff - flyStartTime) * flySpeed * 0.001;

		if ((timeDiff < maxFlyEndTime) && (flySpeed != 0.0) && (flyDistance < CUSTOM1.a))
		{
			vec3 startOrigin = CUSTOM1.xyz;
			vec3 finalOrigin = currentOrigin;
			
			// Origin shifted out of the lidar unit:
//			vec3 shiftedStartOrigin = startOrigin;
			vec3 shiftedStartOrigin = startOrigin + flyStartOriginShift * normalize(finalOrigin - startOrigin);

			// CUSTOM1.a has line length precalculated
			float fraction = clamp(flyDistance / CUSTOM1.a, 0.0, 1.0);
			vec3 currentOrigin = mix(shiftedStartOrigin, finalOrigin, fraction);
			
			pointSize = mix(flyStartPointSize, flyEndPointSize, fraction);

			vec4 interpolatedColor = mix(flyStartAlbedo, flyEndAlbedo, fraction);
			fragmentAlbedo = interpolatedColor.rgb;
			fragmentAlpha = interpolatedColor.a;
			
			// I don't understand why this needs 1/pointSize as multiplier...
			// The whole billboarding-solution was actually quite
			// shooting in the dark until it worked, though...
			// (Like why can't I just translate the VERTEX without any matrices here?)
			VERTEX = VERTEX + (1.0 / pointSize) * (mat3(VIEW_MATRIX) * (currentOrigin - finalOrigin));
			
			timeDiff = 0.0;
		}
		else if (flySpeed != 0.0)
		{
			timeDiff = max((timeDiff - CUSTOM1.a / (flySpeed * 0.001) + flyStartTime), 0.0);
			pointSize = mix(fadeoutStartPointSize, fadeoutEndPointSize, clamp(timeDiff / (fadeoutEndTime - fadeoutStartTime), 0.0, 1.0));
			fragmentAlbedo = pointColors[pointColorIndex].rgb;
			fragmentAlpha = pointColors[pointColorIndex].a;
//			pointSize = mix(initialPointSize, finalPointSize, smoothstep(initialPointSizeTime, finalPointSizeTime, timeDiff));
		}
		
		if (timeDiff > fadeoutEndTime)
		{
			fragmentAlbedo = pointColors[pointColorIndex].rgb;
			fragmentAlpha = fadeoutEndAlpha;
		}
		else if (timeDiff > fadeoutStartTime)
		{
			float fraction = (timeDiff - fadeoutStartTime) / (fadeoutEndTime - fadeoutStartTime);
			pointSize = fadeoutStartPointSize + fraction * (fadeoutEndPointSize - fadeoutStartPointSize);
			fragmentAlpha = clamp(fadeoutStartPointSize + fraction * (fadeoutEndPointSize - fadeoutStartPointSize), 0.0, 1.0);
			fragmentAlbedo = pointColors[pointColorIndex].rgb;
		}
		else if (timeDiff > hitAlbedoAttackHighTime) // && < hitAlbedoAttackFadeoutTime)
		{
			float fraction = smoothstep(hitAlbedoAttackHighTime, hitAlbedoAttackFadeoutTime, timeDiff); // (timeDiff - hitAlbedoAttackHighTime) / (hitAlbedoAttackFadeoutTime - hitAlbedoAttackHighTime);
			vec4 color = mix(hitAlbedoAttackColor, pointColors[pointColorIndex], fraction);
			pointSize = mix(hitAlbedoAttackPointSize, fadeoutStartPointSize, fraction);
			fragmentAlbedo = color.rgb;
			fragmentAlpha = color.a;
		}
		else if (timeDiff != 0.0)	// < hitAlbedoAttackHighTime
		{
			float fraction = -1.0 + 2.0 * smoothstep(-hitAlbedoAttackHighTime, hitAlbedoAttackHighTime, timeDiff); // (timeDiff - hitAlbedoAttackHighTime) / (hitAlbedoAttackFadeoutTime - hitAlbedoAttackHighTime);
			vec4 color = mix(flyEndAlbedo, hitAlbedoAttackColor, fraction);
			pointSize = mix(flyEndPointSize, hitAlbedoAttackPointSize, fraction);
			fragmentAlbedo = color.rgb;
			fragmentAlpha = color.a;
		}
		

		// Billboard:
		VERTEX = currentOrigin + (mat3(INV_VIEW_MATRIX) * (pointSize * (VERTEX - currentOrigin)));
		
	}
}

void fragment() {
	if (discardFragment != 0.0)
	{
		discard;
	}
	else
	{
		// It's possible to use some non-typical optimization here
		// because the face is billboarded
		// (screen's X&Y-axes always align with the UVs's axes)
		
		float xRangeLow = UV.x - abs(dFdx(UV.x)) * 0.5;
		float xRangeHigh = UV.x + abs(dFdx(UV.x)) * 0.5;
		float yRangeLow = UV.y - abs(dFdy(UV.y)) * 0.5;
		float yRangeHigh = UV.y + abs(dFdy(UV.y)) * 0.5;
		
//		float xRangeLow = UV.x;
//		float xRangeHigh = UV.x + dFdx(UV.x);
//		float yRangeLow = UV.y;
//		float yRangeHigh = UV.y + dFdy(UV.y);

//		vec3 dbgColor = vec3(0.0, 0.0, 0.0);
		
		// Handle some trivial outlying cases to prevent them being anti-aliased.
		if ((yRangeLow > 1.0) ||		// Top
				(xRangeHigh < -1.0) ||	// Left
				(xRangeLow > 1.0) ||	// Right
				((xRangeHigh <= 0.0) && (yRangeLow >= 0.0) && ((xRangeHigh * xRangeHigh + yRangeLow * yRangeLow) > 1.0)) ||		// Top left
				((xRangeLow >= 0.0) && (yRangeLow >= 0.0) && ((xRangeLow * xRangeLow + yRangeLow * yRangeLow) > 1.0)) ||			// Top right
				((xRangeHigh <= 0.0) && (yRangeHigh <= 0.0) && ((xRangeHigh * xRangeHigh + yRangeHigh * yRangeHigh) > 1.0)) ||	// Bottom left
				((xRangeLow >= 0.0) && (yRangeHigh <= 0.0) && ((xRangeLow * xRangeLow + yRangeHigh * yRangeHigh) > 1.0))			// Bottom right
		)
		{
			discard;
		}
		else
		{
			if 		(((xRangeLow * xRangeLow + yRangeLow * yRangeLow) < 1.0) &&
					((xRangeLow * xRangeLow + yRangeHigh * yRangeHigh) < 1.0) &&
					((xRangeHigh * xRangeHigh + yRangeLow * yRangeLow) < 1.0) &&
					((xRangeHigh * xRangeHigh + yRangeHigh * yRangeHigh) < 1.0))
			{
				// Whole range is inside the circle
				// -> Use only the middle point (likely good enough)
				ALPHA = 1.0 - smoothstep(0.0, 1.0, sqrt(UV.x * UV.x + UV.y *UV.y));
				
//				dbgColor.b = 1.0;
			}
			else
			{
				// This is "edge case" -> anti-alias

				float alphaSum = 0.0;
				
				for (int ix = 0 ; ix < antiAlias; ix++)
				{
					float x = xRangeLow + ((float(ix) + 0.5) / float(antiAlias) * (xRangeHigh - xRangeLow));
					for (int iy = 0; iy < antiAlias; iy++)
					{
						float y = yRangeLow + ((float(iy) + 0.5) / float(antiAlias) * (yRangeHigh - yRangeLow));
						float squaredDist = (x * x) + (y * y);
						
						alphaSum += 1.0 - smoothstep(0.0, 1.0, sqrt(squaredDist));
					}
				}
				ALPHA = clamp(alphaSum / float(antiAlias * antiAlias), 0.0, 1.0);
				
//				dbgColor.r = 1.0;
//				dbgColor.g = -1.0;
//				dbgColor.b = 1.0;
			}

//			ALBEDO = pointColors[int(UV2.y + 0.5) & 0x0F].rgb + dbgColor;
			ALBEDO = fragmentAlbedo;
			
	//		ALBEDO = pointColors[int(UV2.y + 0.5) & 0x0F].xyz;
		//	ALBEDO = COLOR.rgb;
	//		ALBEDO.r = UV.x;
	//		ALBEDO.b = UV.y;
			ALPHA *= fragmentAlpha;
			
//			ALPHA = max(ALPHA, 0.5);
		}
	}
}
