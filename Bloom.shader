Shader "Unlit/Bloom"
{
	Properties 
	{
		_MainTex ("Texture", 2D) = "white" {}
	}

	CGINCLUDE

	// 盒采样
	float3 SampleBox(float2 uv,sampler2D Tex,float4 Tex_Size,float sample_Delta)
	{
		float4 o = Tex_Size.xyxy * float2(-sample_Delta, sample_Delta).xxyy;
		float3 s = tex2D(Tex,uv + o.xy) + tex2D(Tex,uv + o.zy) +
				   tex2D(Tex,uv + o.xw) + tex2D(Tex,uv + o.zw);
		return s * 0.25f;
	}


	#include "UnityCG.cginc"

	sampler2D _MainTex,_SourceTex;
	// 该变量获取贴图单一像素尺寸
	float4 _MainTex_TexelSize;
	float _Intensity;

	struct a2v {
		float4 vertex : POSITION0;
		float2 uv : TEXCOORD0;
	};

	struct v2f {
		float4 pos : SV_POSITION;
		float2 uv : TEXCOORD0;
	};


	// Unity后处理的网格是一个全屏的四边形
	// 转到裁剪空间 [-1,+1]
	v2f VertexProgram (a2v v) {
		v2f o;

		// Unity内置的MVP变换函数
		o.pos = UnityObjectToClipPos(v.vertex);
		o.uv = v.uv;
		return o;
	}

	ENDCG

    SubShader
    {
		Pass 
		{ 
			// 0
			
			CGPROGRAM

			#pragma vertex VertexProgram
			#pragma fragment FragmentProgram

			float4 _Filter;
			

			float3 Prefilter (float3 c) {
				float brightness = max(c.r, max(c.g, c.b));
			
				float soft = brightness - _Filter.y;
				soft = clamp(soft, 0, _Filter.z);
				soft = soft * soft * _Filter.w;

				float contribution = max(soft, brightness - _Filter.x);
				contribution /= max(brightness, 0.00001);

				return c * contribution;
			}

			float4 FragmentProgram(v2f i) : SV_Target 
			{
				return float4(Prefilter(SampleBox(i.uv,_MainTex,_MainTex_TexelSize, 1.f)), 1);
			}

			ENDCG
		}

		Pass 
		{ 
			// 1

			CGPROGRAM

			#pragma vertex VertexProgram
			#pragma fragment FragmentProgram


			float4 FragmentProgram(v2f i) : SV_Target 
			{
				return float4(SampleBox(i.uv,_MainTex,_MainTex_TexelSize, 1.f), 1);
			}

			ENDCG
		}

		Pass 
		{
			// 2

			// 设混合模式为相加 上采样与下采样效果叠加
			Blend One One

			CGPROGRAM
			
			#pragma vertex VertexProgram
			#pragma fragment FragmentProgram

			float4 FragmentProgram(v2f i) : SV_Target 
			{
				return float4(_Intensity * SampleBox(i.uv,_MainTex,_MainTex_TexelSize, 0.5f), 1.f);
			}
			
			ENDCG
		}

		Pass { 

			// 3 最后一遍将bloom值相加
			CGPROGRAM
			

			#pragma vertex VertexProgram
			#pragma fragment FragmentProgram

			float4 FragmentProgram(v2f i) : SV_Target {
				float4 c = tex2D(_SourceTex, i.uv);
				c.rgb += _Intensity * SampleBox(i.uv,_MainTex,_MainTex_TexelSize, 0.5f);
				return c;
			}
			ENDCG
		}
    }
}
