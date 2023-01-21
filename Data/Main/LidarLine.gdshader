shader_type spatial;

//render_mode cull_disabled, depth_draw_always;
render_mode unshaded, blend_add, world_vertex_coords;	//, depth_prepass_alpha;
//render_mode unshaded, blend_mix, depth_draw_always;

// ReplayTime is divided into two parts to get more resolution.
// For "super slo-mo" float is not enough so remainder is used to
// "fine tune" the locally calculated replay time difference.
uniform float replayTime;
uniform float replayTimeRemainder;

// To prevent lines from being drawn inside the lidar
// (Lines' start position is shifted this amount towards the hit point)
uniform float originShift = 2;

uniform float outOfSightShift_Y = 8.0;

uniform float initialLELineWidthAttackStartTime = 0.0;
uniform float initialLELineWidth = 0.1;

uniform float initialLELineWidthAttackHighTime = 5.0;
uniform float initialLELineWidthAttackHighWidth = 0.5;

uniform float initialLELineWidthAttackEndTime = 0.0;
uniform float initialLELineWidthAttackEndWidth = 0.3;

uniform float finalLELineWidth = 0.2;
uniform float finalLELineWidthTime = 45.0;

uniform float initialTELineWidthAttackStartTime = 0.0;
uniform float initialTELineWidth = 0.1;

uniform float initialTELineWidthAttackHighTime = 5.0;
uniform float initialTELineWidthAttackHighWidth = 0.5;

uniform float initialTELineWidthAttackEndTime = 0.0;
uniform float initialTELineWidthAttackEndWidth = 0.3;

uniform float finalTELineWidth = 0.2;
uniform float finalTELineWidthTime = 45.0;


uniform float initialAlbedoAttackStartTime = 0.0;
uniform float initialAlbedoAttackStartGamma = 5.0;
uniform float initialAlbedoAttackHighTime = 5.0;
uniform float initialAlbedoAttackHighGamma = 5.0;
uniform float initialAlbedoAttackEndTime = 10.0;
uniform float initialAlbedoAttackEndColorGamma = 5.0;

/*
uniform float initialLEAlbedoAttackStartTime = 0.0;
uniform float initialLEAlbedoAttackStartGamma = 5.0;
uniform float initialLEAlbedoAttackHighTime = 5.0;
uniform float initialLEAlbedoAttackHighGamma = 5.0;
uniform float initialLEAlbedoAttackEndTime = 10.0;
uniform float initialLEAlbedoAttackEndColorGamma = 5.0;

uniform float initialTEAlbedoAttackStartTime = 0.0;
uniform float initialTEAlbedoAttackStartGamma = 0.0;
uniform float initialTEAlbedoAttackHighTime = 5.0;
uniform float initialTEAlbedoAttackHighGamma = 5.0;
uniform float initialTEAlbedoAttackEndTime = 10.0;
uniform float initialTEAlbedoAttackEndColorGamma = 5.0;
*/

uniform vec4 initialAlbedoAttackColor : source_color;

uniform float fadeOutStartTime = 5.0;
uniform float fadeOutEndTime = 50.0;
uniform float fadeOutGamma = 0.5;

/*
uniform float TEFadeOutStartTime = 5.0;
uniform float TEFadeOutEndTime = 50.0;
uniform float TEFadeOutGamma = 0.5;

uniform float LEFadeOutStartTime = 5.0;
uniform float LEFadeOutEndTime = 50.0;
uniform float LEFadeOutGamma = 0.5;
*/

uniform float leadingEdgeFlyStartTime = 0.0;
uniform float leadingEdgeFlySpeed = 1000.0;

uniform float trailingEdgeFlyStartTime = 10.0;
uniform float trailingEdgeFlySpeed = 3.5;

uniform float disappearanceTime = 200;

// Indexes here are of type LSItemType from LidarDataStorage.gd
// If alpha == 0, no point is drawn
uniform vec4 pointColors[16] : source_color;

uniform int lineAntiAliasing = 10;

uniform float antialiasingGamma = 2.2;

uniform int pointSkip = 0;

//uniform vec4 pointOkColor : hint_color = vec4(0.0, 1.0, 0.0, 1.0);
//uniform vec4 pointOkColor : hint_color = vec4(0.0, 1.0, 0.0, 1.0);

vec3 getFlyingLineOrigin(float time, float startTime, vec3 startOrigin, float flySpeed, vec3 endOrigin, float lineLength)
{
	float flyDistance = (time - startTime) * flySpeed * 0.001;

//	float lineLength = length(endOrigin - startOrigin);
	
//	float fraction = clamp((time - startTime) / (endTime - startTime), 0.0, 1.0);
	float fraction = clamp(flyDistance / lineLength, 0.0, 1.0);
	return mix(startOrigin, endOrigin, fraction);
}


float getLineWidth(float timeDiff,
		float initialLineWidthAttackStartTime,
		float initialLineWidth,

		float initialLineWidthAttackHighTime,
		float initialLineWidthAttackHighWidth,

		float initialLineWidthAttackEndTime,
		float initialLineWidthAttackEndWidth,

		float finalLineWidth,
		float finalLineWidthTime)
{
	float lineWidth;
	
	if (timeDiff >= finalLineWidthTime)
	{
		// Final line width
		lineWidth = finalLineWidth;
	}
	else if (timeDiff >= initialLineWidthAttackEndTime)
	{
		// Between the end of initial attack and finalLineWidthTime
		float fraction = (timeDiff - initialLineWidthAttackEndTime) / (finalLineWidthTime - initialLineWidthAttackEndTime);
		lineWidth = mix(initialLineWidthAttackEndWidth, finalLineWidth, fraction);
	}
	else if (timeDiff >= initialLineWidthAttackHighTime)
	{
		// Initial attack decaying
		float fraction = (timeDiff - initialLineWidthAttackHighTime) / (initialLineWidthAttackEndTime - initialLineWidthAttackHighTime);
		lineWidth = mix(initialLineWidthAttackHighWidth, initialLineWidthAttackEndWidth, fraction);
	}
	else if (timeDiff >= initialLineWidthAttackStartTime)
	{
		// Initial attack decaying
		float fraction = (timeDiff - initialLineWidthAttackStartTime) / (initialLineWidthAttackHighTime - initialLineWidthAttackStartTime);
		lineWidth = mix(initialLineWidth , initialLineWidthAttackHighWidth, fraction);
	}
	else
	{
		lineWidth = initialLineWidth;
	}
	
	return lineWidth;
}

varying flat vec3 fragmentAlbedo;
varying flat float fragmentAlpha;
//varying float fragmentAlphaGammaCorrection;
varying float triangleWidth;
varying flat float discardFragment;	// This is bool...
varying flat float fragmentTimeDiff;

void vertex() {
//	return;
	
	float timeDiff = replayTime - UV2.x;	// UV2.x = shotTime
	timeDiff += replayTimeRemainder;
	int pointColorIndex = int(UV2.y + 0.5) & 0x0F;
	float pointAlpha = pointColors[pointColorIndex].a;
	int pointIndex = int(CUSTOM0.a);
	
	if ((timeDiff < 0.0) || (timeDiff >= disappearanceTime) || (pointAlpha == 0.0) || 
			(pointSkip == 0) || (pointIndex % pointSkip != 0))
	{
		// Face not visible yet or no longer or the color is set to hide this type
		// -> Throw it out of sight
		VERTEX.y += outOfSightShift_Y;
		UV2.y = 0.0;
		discardFragment = 1.0;
//		VERTEX.y += 10.0;
	}
	else
	{
		discardFragment = 0.0;
		fragmentTimeDiff = timeDiff;
//		vec3 startOrigin = CUSTOM1.xyz;
//		vec3 finalOrigin = CUSTOM0.xyz;
		vec3 startOrigin = (MODEL_MATRIX * vec4(CUSTOM1.xyz, 1.0)).xyz;
		vec3 finalOrigin = (MODEL_MATRIX * vec4(CUSTOM0.xyz, 1.0)).xyz;
		
		vec3 fromStartOriginToFinalOrigin = finalOrigin - startOrigin;
		vec3 fromStartOriginToCamera = INV_VIEW_MATRIX[3].xyz - startOrigin;
		
		// TODO: zero from cross-product not handled (very unlikely to happen though)
		// rightAngleVec becomes 0.5 mm length here so it is possible to set widths as mm
		vec3 rightAngleVec = -0.0005 * normalize(cross(fromStartOriginToFinalOrigin, fromStartOriginToCamera));
		float lineWidth_ThisEnd;
		float lineWidth_OtherEnd;
		
		// Origin shifted out of the lidar unit:
		vec3 shiftedStartOrigin = startOrigin + originShift * normalize(finalOrigin - startOrigin);
		
		int corner = int(UV2.y + 0.5) >> 4 & 0x0F;

		switch(corner)
		{
			case 0:
			case 1:
			case 5:
				// Optimization: CUSTOM1.a has precalculated line length
				VERTEX = getFlyingLineOrigin(timeDiff, trailingEdgeFlyStartTime, shiftedStartOrigin, trailingEdgeFlySpeed, finalOrigin, CUSTOM1.a);

				lineWidth_ThisEnd = getLineWidth(timeDiff,
						initialTELineWidthAttackStartTime,
						initialTELineWidth,
						initialTELineWidthAttackHighTime,
						initialTELineWidthAttackHighWidth,
						initialTELineWidthAttackEndTime,
						initialTELineWidthAttackEndWidth,
						finalTELineWidth,
						finalTELineWidthTime);
						
				lineWidth_OtherEnd = getLineWidth(timeDiff,
						initialLELineWidthAttackStartTime,
						initialLELineWidth,
						initialLELineWidthAttackHighTime,
						initialLELineWidthAttackHighWidth,
						initialLELineWidthAttackEndTime,
						initialLELineWidthAttackEndWidth,
						finalLELineWidth,
						finalLELineWidthTime);
/*
				initialAlbedoAttackStartTime = initialTEAlbedoAttackStartTime;
				initialAlbedoAttackStartGamma = initialTEAlbedoAttackStartGamma;
				initialAlbedoAttackHighTime = initialTEAlbedoAttackHighTime;
				initialAlbedoAttackHighGamma = initialTEAlbedoAttackHighGamma;
				initialAlbedoAttackEndTime = initialTEAlbedoAttackEndTime;
				initialAlbedoAttackEndColorGamma = initialTEAlbedoAttackEndColorGamma;

				fadeOutStartTime = TEFadeOutStartTime;
				fadeOutEndTime = TEFadeOutEndTime;
				fadeOutGamma = TEFadeOutGamma;
*/
				break;
			case 2:
			case 3:
			case 4:
				// Optimization: CUSTOM1.a has precalculated line length
				VERTEX = getFlyingLineOrigin(timeDiff, leadingEdgeFlyStartTime, shiftedStartOrigin, leadingEdgeFlySpeed, finalOrigin, CUSTOM1.a);

				lineWidth_ThisEnd = getLineWidth(timeDiff,
						initialLELineWidthAttackStartTime,
						initialLELineWidth,
						initialLELineWidthAttackHighTime,
						initialLELineWidthAttackHighWidth,
						initialLELineWidthAttackEndTime,
						initialLELineWidthAttackEndWidth,
						finalLELineWidth,
						finalLELineWidthTime);

				lineWidth_OtherEnd = getLineWidth(timeDiff,
						initialTELineWidthAttackStartTime,
						initialTELineWidth,
						initialTELineWidthAttackHighTime,
						initialTELineWidthAttackHighWidth,
						initialTELineWidthAttackEndTime,
						initialTELineWidthAttackEndWidth,
						finalTELineWidth,
						finalTELineWidthTime);

/*
				initialAlbedoAttackStartTime = initialLEAlbedoAttackStartTime;
				initialAlbedoAttackStartGamma = initialLEAlbedoAttackStartGamma;
				initialAlbedoAttackHighTime = initialLEAlbedoAttackHighTime;
				initialAlbedoAttackHighGamma = initialLEAlbedoAttackHighGamma;
				initialAlbedoAttackEndTime = initialLEAlbedoAttackEndTime;
				initialAlbedoAttackEndColorGamma = initialLEAlbedoAttackEndColorGamma;

				fadeOutStartTime = LEFadeOutStartTime;
				fadeOutEndTime = LEFadeOutEndTime;
				fadeOutGamma = LEFadeOutGamma;
*/
				break;
		}

		
/*
		float initialAlbedoAttackStartTime;
		float initialAlbedoAttackStartGamma;
		float initialAlbedoAttackHighTime;
		float initialAlbedoAttackHighGamma;
		float initialAlbedoAttackEndTime;
		float initialAlbedoAttackEndColorGamma;
*/
/*
		float initialAlbedoAttackStartTime = initialLEAlbedoAttackStartTime;
		float initialAlbedoAttackHighTime = initialLEAlbedoAttackHighTime;
		float initialAlbedoAttackEndTime = initialLEAlbedoAttackEndTime;
*/
/*
		float fadeOutStartTime;
		float fadeOutEndTime;
		float fadeOutGamma;
*/
		float xRangeLow = 0.0;
		float xRangeHigh = PI;

		switch(corner)
		{
			case 0:
				VERTEX -= lineWidth_ThisEnd * rightAngleVec;
				UV = vec2(xRangeLow, 1.0);
				triangleWidth = PI;
				break;
			case 1:
				VERTEX += lineWidth_ThisEnd * rightAngleVec;
				UV = vec2(xRangeHigh, 1.0);
				triangleWidth = PI;
				break;
			case 2:
				VERTEX -= lineWidth_ThisEnd * rightAngleVec;
//				UV = vec2(0.0, lineWidth_ThisEnd / lineWidth_OtherEnd * 1.0);
				UV = vec2(xRangeLow, lineWidth_ThisEnd / lineWidth_OtherEnd);
				triangleWidth = 0.0;
//				relativeWidth = lineWidth_ThisEnd / lineWidth_OtherEnd;
//				relativeWidth = 2.0;
				break;
			case 3:
				VERTEX += lineWidth_ThisEnd * rightAngleVec;
				UV = vec2(xRangeLow, 1.0);
				triangleWidth = PI;
				break;
			case 4:
				VERTEX -= lineWidth_ThisEnd * rightAngleVec;
				UV = vec2(xRangeHigh, 1.0);
				triangleWidth = PI;
				break;
			case 5:
				VERTEX += lineWidth_ThisEnd * rightAngleVec;
				UV = vec2(xRangeLow, lineWidth_ThisEnd / lineWidth_OtherEnd);
				triangleWidth = 0.0;

//				relativeWidth = lineWidth_ThisEnd / lineWidth_OtherEnd;
//				relativeWidth = 0.5;
//				UV = vec2(0.0, (lineWidth_ThisEnd / lineWidth_OtherEnd) * 1.0);
				break;
		}
		
//		relativeWidth = UV.y;
		
//		vec3 pointColor = pointColors[int(UV2.y) & 0xF].xyz;
//		COLOR = pointColors[int(UV2.y) & 0xF];
		
		
//		float pointSize = mix(initialPointSize, finalPointSize, smoothstep(initialPointSizeTime, finalPointSizeTime, timeDiff));
		
//		VERTEX = finalOrigin + (mat3(CAMERA_MATRIX) * (VERTEX - finalOrigin) * pointSize);
		
		UV2.y = float(pointColorIndex);
		
//		UV.x = fract(TIME) * 2.0 * PI;
		
		
		// Some varyings fed to fragment shader for slight optimization
		if (timeDiff >= fadeOutEndTime)
		{
			// Line completely faded out
//			ALBEDO = pointColors[int(UV2.y + 0.5) & 0x0F].xyz;
			discardFragment = 1.0;
			//ALPHA = 0.0;
		}
		if (timeDiff >= initialAlbedoAttackEndTime) // && < fadeOutEndTime
		{
			// Line fading out
			fragmentAlbedo = pointColors[int(UV2.y + 0.5) & 0x0F].xyz;
			fragmentAlpha = clamp(pow((1.0 - ((timeDiff - fadeOutStartTime) / (fadeOutEndTime - fadeOutStartTime))), fadeOutGamma), 0.0, 1.0);
		}
		else if (timeDiff >= initialAlbedoAttackHighTime)	 // && < initialAlbedoAttackEndTime
		{
			// Initial attack changing to "normal" fade out
			float colorFraction = pow(((timeDiff - initialAlbedoAttackHighTime) / (initialAlbedoAttackEndTime - initialAlbedoAttackHighTime)), initialAlbedoAttackEndColorGamma);
			fragmentAlbedo = mix(initialAlbedoAttackColor.xyz, pointColors[int(UV2.y + 0.5) & 0x0F].xyz, smoothstep(0.0, 1.0, colorFraction));
			fragmentAlpha = 1.0;
		}
		else if (timeDiff >= initialAlbedoAttackStartTime) // && < initialAlbedoAttackHighTime
		{
			// Initial attack rising up
			float fraction = clamp(((timeDiff - initialAlbedoAttackStartTime) / (initialAlbedoAttackHighTime - initialAlbedoAttackStartTime)), 0.0, 1.0);
			fragmentAlbedo = initialAlbedoAttackColor.xyz;
//			EMISSION = initialAlbedoAttackColor.xyz;
			fragmentAlpha = fraction;
		}
		else
		{
			// Initial attack not started yet, nothing to draw
			// probably not needed at all(?)
			// ALBEDO = pointColors[int(UV2.y + 0.5) & 0x0F].xyz;
			discardFragment = 1.0;
			//ALPHA = 0.0;
		}
		
	}



}

/*
float getLineAlpha(vec2 uv)
{
//	return sin(uv.x);
//	return max(1.0 - step(0, uv.x), step(PI, uv.x));
	return 1.0;
}

void fragment() {
//	ALBEDO = fragmentAlbedo;
//	ALPHA = clamp(pow(fragmentAlpha * sin(UV.x), fragmentAlphaGammaCorrection), 0.0, 1.0);

	float timeDiff = replayTime - UV2.x;	// UV2.x = shotTime
	int pointColorIndex = int(UV2.y + 0.5) & 0x0F;
	float pointAlpha = pointColors[pointColorIndex].a;
	
	if ((timeDiff >= 0.0) && (timeDiff < disappearanceTime) && (pointAlpha != 0.0))
	{
		// ifs in decreasing times since it's more likely to "later" ones
		// to be run more frequently

		if (timeDiff >= fadeOutEndTime)
		{
			// Line completely faded out
//			ALBEDO = pointColors[int(UV2.y + 0.5) & 0x0F].xyz;
			discard;
			//ALPHA = 0.0;
		}
		if (timeDiff >= initialAlbedoAttackEndTime) // && < fadeOutEndTime
		{
			// Line fading out
			ALBEDO = pointColors[int(UV2.y + 0.5) & 0x0F].xyz;
			ALPHA = clamp(getLineAlpha(UV) * pow((1.0 - ((timeDiff - fadeOutStartTime) / (fadeOutEndTime - fadeOutStartTime))), fadeOutGamma), 0.0, 1.0);
		}
		else if (timeDiff >= initialAlbedoAttackHighTime)	 // && < initialAlbedoAttackEndTime
		{
			// Initial attack changing to "normal" fade out
			float colorFraction = pow(((timeDiff - initialAlbedoAttackHighTime) / (initialAlbedoAttackEndTime - initialAlbedoAttackHighTime)), initialAlbedoAttackEndColorGamma);
			ALBEDO = mix(initialAlbedoAttackColor.xyz, pointColors[int(UV2.y + 0.5) & 0x0F].xyz, colorFraction);
			ALPHA = getLineAlpha(UV);
		}
		else if (timeDiff >= initialAlbedoAttackStartTime) // && < initialAlbedoAttackHighTime
		{
			// Initial attack rising up
			float fraction = clamp(getLineAlpha(UV) * ((timeDiff - initialAlbedoAttackStartTime) / (initialAlbedoAttackHighTime - initialAlbedoAttackStartTime)), 0.0, 1.0);
			ALBEDO = initialAlbedoAttackColor.xyz;
//			EMISSION = initialAlbedoAttackColor.xyz;
			ALPHA = fraction;
		}
		else
		{
			// Initial attack not started yet, nothing to draw
			// probably not needed at all(?)
			// ALBEDO = pointColors[int(UV2.y + 0.5) & 0x0F].xyz;
			discard;
			//ALPHA = 0.0;
		}
		
	} // if ((timeDiff >= 0.0) && (timeDiff < disappearanceTime) && (pointAlpha != 0.0))
	else
	{
		// else face not visible yet or no longer or the color is set to hide this type
		//  -> nothing needs to be done as the vertex is already thrown out of sight by vertex shader.
		// (Actually it seems likely that vertex shader is getting differing replayTimes (uniform)
		// so let's hide the line here...
		discard;
//		ALPHA = 0.0;
	}

//	ALBEDO = pointColors[int(UV2.y + 0.5) & 0x0F].xyz;
//	ALBEDO = COLOR.rgb;
//	ALPHA = pointColors[int(UV2.y + 0.5) & 0x0F].a;
}
*/

void fragment() {

	if (discardFragment == 0.0)
	{
		float timeDiff = fragmentTimeDiff;	// replayTime - UV2.x;	// UV2.x = shotTime
		int pointColorIndex = int(UV2.y + 0.5) & 0x0F;
		float pointAlpha = pointColors[pointColorIndex].a;	
		float preAlpha = fragmentAlpha;
//		ALBEDO = vec3(0.0, 1.0, 0.0);
//		EMISSION = fragmentAlbedo;
		ALBEDO = fragmentAlbedo;
		
		
		
		
		
		
		
		
		
/*
		// ifs in decreasing times since it's more likely to "later" ones
		// to be run more frequently

		if (timeDiff >= fadeOutEndTime)
		{
			// Line completely faded out
//			ALBEDO = pointColors[int(UV2.y + 0.5) & 0x0F].xyz;
			discard;
			//ALPHA = 0.0;
		}
		if (timeDiff >= initialAlbedoAttackEndTime) // && < fadeOutEndTime
		{
			// Line fading out
			ALBEDO = pointColors[int(UV2.y + 0.5) & 0x0F].xyz;
			preAlpha = clamp(pow((1.0 - ((timeDiff - fadeOutStartTime) / (fadeOutEndTime - fadeOutStartTime))), fadeOutGamma), 0.0, 1.0);
		}
		else if (timeDiff >= initialAlbedoAttackHighTime)	 // && < initialAlbedoAttackEndTime
		{
			// Initial attack changing to "normal" fade out
			float colorFraction = pow(((timeDiff - initialAlbedoAttackHighTime) / (initialAlbedoAttackEndTime - initialAlbedoAttackHighTime)), initialAlbedoAttackEndColorGamma);
			ALBEDO = mix(initialAlbedoAttackColor.xyz, pointColors[int(UV2.y + 0.5) & 0x0F].xyz, colorFraction);
			preAlpha = 1.0;
		}
		else if (timeDiff >= initialAlbedoAttackStartTime) // && < initialAlbedoAttackHighTime
		{
			// Initial attack rising up
			float fraction = clamp(((timeDiff - initialAlbedoAttackStartTime) / (initialAlbedoAttackHighTime - initialAlbedoAttackStartTime)), 0.0, 1.0);
			ALBEDO = initialAlbedoAttackColor.xyz;
//			EMISSION = initialAlbedoAttackColor.xyz;
			preAlpha = fraction;
		}
		else
		{
			// Initial attack not started yet, nothing to draw
			// probably not needed at all(?)
			// ALBEDO = pointColors[int(UV2.y + 0.5) & 0x0F].xyz;
			discard;
			//ALPHA = 0.0;
		}
*/
		
		if (lineAntiAliasing == -1)
		{
			float derivXWidth = sqrt(dFdx(UV.x) * dFdx(UV.x) + dFdy(UV.x) * dFdy(UV.x));
			float derivYWidth = sqrt(dFdx(UV.y) * dFdx(UV.y) + dFdy(UV.y) * dFdy(UV.y));
			
			float integrXStart = UV.x - derivXWidth * 0.5;
			float integrXEnd = UV.x + derivXWidth * 0.5;

			float integrYStart = UV.y - derivYWidth * 0.5;
			float integrYEnd = UV.y + derivYWidth * 0.5;

	//		float clampedDerivStart = clamp(derivStart, 0.0, triangleWidth);
	//		float clampedDerivEnd = clamp(derivEnd, 0.0, triangleWidth);









	//		float derivStart = UV.x - fwidth(UV.x) * 0.5;
	//		float derivEnd = UV.x + fwidth(UV.x) * 0.5;
	//		float integral = 1.0;
			
	//		if ((derivStart >= 0.0) && (derivStart <= PI) && (derivEnd >= 0.0) && (derivEnd <= PI))
	//		{
//				float rawIntegral = abs((0.5 + 0.5 * cos(integrXStart / integrYStart)) - (0.5 + 0.5 * cos(integrXEnd / integrYEnd)));
				float rawIntegral = abs((0.5 + 0.5 * cos(integrXStart)) - (0.5 + 0.5 * cos(integrXEnd)));
	//			float rawIntegral = abs((0.5 + 0.5 * cos(clamp(derivStart / UV.y, 0.0, triangleWidth / UV.y))) - (0.5 + 0.5 * cos(clamp(derivEnd / UV.y, 0.0, triangleWidth / UV.y))));
	//			float rawIntegral = abs(0.5 + 0.5 * (cos(clamp(derivStart / UV.y, 0.0, triangleWidth / UV.y)) - cos(clamp(derivEnd / UV.y, 0.0, triangleWidth / UV.y))));
				float areaRadWidth = abs(integrXEnd - integrXStart);
				float integral = 2.0 * rawIntegral / areaRadWidth;
	//		}
	//		else
	//		{
	//			ALBEDO.r = 1.0;
	//		}
			
	//Debug:		ALBEDO.r = integral;
			
			ALPHA = clamp(preAlpha * integral, 0.0, 1.0);
		}
		else if (lineAntiAliasing < -100)
		{
			int localAA = -(lineAntiAliasing - 100);
			float derivXWidth = sqrt(dFdx(UV.x) * dFdx(UV.x) + dFdy(UV.x) * dFdy(UV.x));
//			float derivYWidth = sqrt(dFdx(UV.y) * dFdx(UV.y) + dFdy(UV.y) * dFdy(UV.y));
			
			float integrXStart = UV.x - derivXWidth * 0.5;
			float integrXEnd = UV.x + derivXWidth * 0.5;

	//		float integrYStart = UV.y - derivYWidth * 0.5;
	//		float integrYEnd = UV.y + derivYWidth * 0.5;

	//		float clampedDerivStart = clamp(derivStart, 0.0, triangleWidth);
	//		float clampedDerivEnd = clamp(derivEnd, 0.0, triangleWidth);

			float alphaSum = 0.0;

			for (int i = 0; i < localAA; i++)
			{
//				for (int ii = 0; ii < lineAntiAliasing; ii++)
				{
					// 2D:
//					float uvxxVal = UV.x + uvxxDiff * float(i) / float(lineAntiAliasing) +
//							UV.x + uvxyDiff * float(ii) / float(lineAntiAliasing);
//					float uvyxVal = UV.y + uvyxDiff * float(i) / float(lineAntiAliasing) +
//							UV.y + uvyxDiff * float(ii) / float(lineAntiAliasing);
//
//					alphaSum += sin(clamp((uvxxVal / uvyxVal), 0.0, PI));

					float uvxxVal = integrXStart + (integrXEnd - integrXStart) * float(i) / float(-lineAntiAliasing);
//					float uvyxVal = UV.y + uvyxDiff * float(i) / float(lineAntiAliasing);
					
//					alphaSum += sin(clamp((uvxxVal / UV.y), 0.0, PI));
					float angle = uvxxVal / UV.y;
					if ((angle >= 0.0) && (angle < triangleWidth / UV.y))
//					if ((angle >= 0.0) && (angle < PI))
					{
						alphaSum += sin(uvxxVal / UV.y);
//						alphaSum += sin(clamp((uvxxVal / UV.y), 0.0, triangleWidth / UV.y));
					}
				}
			}
			
			ALPHA = clamp(preAlpha * pow(alphaSum / float(localAA), antialiasingGamma), 0.0, 1.0);
		}
		else if (lineAntiAliasing < -1)
		{
			float UVxxDeriv = dFdx(UV.x);
			float UVxyDeriv = dFdy(UV.x);
			
			
			float derivXWidth = sqrt(UVxxDeriv * UVxxDeriv + UVxyDeriv * UVxyDeriv);
//			float derivYWidth = sqrt(dFdx(UV.y) * dFdx(UV.y) + dFdy(UV.y) * dFdy(UV.y));
			
			float integrXStart = UV.x - derivXWidth * 0.5;
			float integrXEnd = UV.x + derivXWidth * 0.5;

	//		float integrYStart = UV.y - derivYWidth * 0.5;
	//		float integrYEnd = UV.y + derivYWidth * 0.5;

	//		float clampedDerivStart = clamp(derivStart, 0.0, triangleWidth);
	//		float clampedDerivEnd = clamp(derivEnd, 0.0, triangleWidth);

			if ((integrXStart <= 0.0) && 
				(integrXEnd >= PI))
			{
				// 0.636619772367581 = integrated of sin(0...PI)

				ALPHA = pow(0.636619772367581 * derivXWidth / PI, antialiasingGamma);
//				ALPHA = 1.0;
//				ALBEDO.r = 1.0;

			}
			else
			{
				float alphaSum = 0.0;

				for (int i = 0; i < -lineAntiAliasing; i++)
				{
	//				for (int ii = 0; ii < lineAntiAliasing; ii++)
					{
						// 2D:
//						float uvxxVal = UV.x + uvxxDiff * float(i) / float(lineAntiAliasing) +
//								UV.x + uvxyDiff * float(ii) / float(lineAntiAliasing);
//						float uvyxVal = UV.y + uvyxDiff * float(i) / float(lineAntiAliasing) +
//								UV.y + uvyxDiff * float(ii) / float(lineAntiAliasing);
//
//						alphaSum += sin(clamp((uvxxVal / uvyxVal), 0.0, PI));

						float uvxxVal = integrXStart + (integrXEnd - integrXStart) * float(i) / float(-lineAntiAliasing);
	//					float uvyxVal = UV.y + uvyxDiff * float(i) / float(lineAntiAliasing);
						
	//					alphaSum += sin(clamp((uvxxVal / UV.y), 0.0, PI));
						float angle = uvxxVal / UV.y;
						if ((angle >= 0.0) && (angle < triangleWidth / UV.y))
						{
							alphaSum += sin(uvxxVal / UV.y);
	//						alphaSum += sin(clamp((uvxxVal / UV.y), 0.0, triangleWidth / UV.y));
						}
					}
				}
				
				ALPHA = clamp(preAlpha * pow(alphaSum / float(-lineAntiAliasing), antialiasingGamma), 0.0, 1.0);
				
//				ALBEDO.g = abs(UV.x);
//				ALBEDO.r = abs(UVxxDeriv);
//				ALBEDO.b = abs(UVxxDeriv);
//				ALPHA = 1.0;
				
//				ALBEDO.r = derivXWidth;
			}
		}
		else if (lineAntiAliasing == 0)
		{
			ALPHA = clamp(preAlpha * sin(clamp(UV.x / UV.y, 0.0, PI)), 0.0, 1.0);
		}
		else
		{
			float uvxxDiff = dFdx(UV.x);
			float uvxyDiff = dFdy(UV.x);
			float uvyxDiff = dFdx(UV.y);
			float uvyyDiff = dFdy(UV.y);

			float alphaSum = 0.0;
			
			for (int i = 0; i < lineAntiAliasing; i++)
			{
//				for (int ii = 0; ii < lineAntiAliasing; ii++)
				{
					// 2D:
//					float uvxxVal = UV.x + uvxxDiff * float(i) / float(lineAntiAliasing) +
//							UV.x + uvxyDiff * float(ii) / float(lineAntiAliasing);
//					float uvyxVal = UV.y + uvyxDiff * float(i) / float(lineAntiAliasing) +
//							UV.y + uvyxDiff * float(ii) / float(lineAntiAliasing);
//
//					alphaSum += sin(clamp((uvxxVal / uvyxVal), 0.0, PI));

					// Horiz:
					float uvxxVal = UV.x + uvxxDiff * float(i) / float(lineAntiAliasing);
					float uvyxVal = UV.y + uvyxDiff * float(i) / float(lineAntiAliasing);
					// Vert:
					float uvxyVal = UV.x + uvxyDiff * float(i) / float(lineAntiAliasing);
					float uvyyVal = UV.y + uvyyDiff * float(i) / float(lineAntiAliasing);
					
					alphaSum += sin(clamp((uvxxVal / uvyxVal), 0.0, PI));
					alphaSum += sin(clamp((uvxyVal / uvyyVal), 0.0, PI));
				}
			}
			
//2D:			ALPHA = clamp(preAlpha * alphaSum / float(lineAntiAliasing * lineAntiAliasing), 0.0, 1.0);
			ALPHA = clamp(preAlpha * alphaSum / float(lineAntiAliasing * 2), 0.0, 1.0);
		}
			
		
//		ALBEDO.r = clamp((UV.x + PI * 0.5) / (PI * 2.0), 0.0, 1.0);
		
//		if ((UV.x > PI * 0.49) && (UV.x < PI * 0.51))
//		{
//			ALBEDO.r = 0.0;
//		}
//		if ((UV.x > 0.0) && (UV.x < PI))
		{
//			ALBEDO.b = 0.5 + 0.5 * sin((UV.x * relativeWidth) *8.0);
// THIS:			ALBEDO.b = 0.5 + 0.5 * -cos((UV.x / UV.y) * 2.0 * PI * 8.0);
//			ALBEDO.r = 0.5 + 0.5 * -cos((UV.y) * 2.0 * PI * 8.0);
//			ALBEDO.g = UV;	//0.5 + 0.5 * -cos((relativeWidth) * 2.0 * PI * 8.0);
//			ALBEDO.b = UV.y;
		}
		
		
	} // if ((timeDiff >= 0.0) && (timeDiff < disappearanceTime) && (pointAlpha != 0.0))
	else
	{
		// else face not visible yet or no longer or the color is set to hide this type
		//  -> nothing needs to be done as the vertex is already thrown out of sight by vertex shader.
		// (Actually it seems likely that vertex shader is getting differing replayTimes (uniform)
		// so let's hide the line here...
		discard;
//		ALPHA = 0.0;
	}

//	ALBEDO = pointColors[int(UV2.y + 0.5) & 0x0F].xyz;
//	ALBEDO = COLOR.rgb;
//	ALPHA = pointColors[int(UV2.y + 0.5) & 0x0F].a;
}
