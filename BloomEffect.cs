using System;
using UnityEngine;

[ExecuteInEditMode,ImageEffectAllowedInSceneView]
public class BloomEffect : MonoBehaviour
{

    public Shader bloomShader;

    [Range(1,16)]
    public int iteration = 1;

    [Range(0, 10)]
    public float threshold = 1;

    [Range(0, 1)]
    public float softThreshold = 0.5f;

    [Range(0, 10)]
    public float intensity = 1;

    [NonSerialized]
    private Material m_Bloom;

    RenderTexture[] textures = new RenderTexture[16];

    const int BoxDownPrefilterPass = 0;
    const int BoxDownPass = 1;
    const int BoxUpPass = 2;
    const int ApplyBloomPass = 3;


    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        if (m_Bloom == null)
        {
            m_Bloom = new Material(bloomShader);
            m_Bloom.hideFlags = HideFlags.HideAndDontSave;
        }


        // 计算阈值
        float knee = threshold * softThreshold;
        Vector4 filter;

        filter.x = threshold;
        filter.y = filter.x - knee;
        filter.z = 2f * knee;

        filter.w = 0.25f / (knee + 0.00001f);

        m_Bloom.SetVector("_Filter", filter);
        m_Bloom.SetFloat("_Intensity", Mathf.GammaToLinearSpace(intensity));

        int width = source.width;
        int height = source.height;
        var format = source.format;


        RenderTexture currentDestination = textures[0] =
          RenderTexture.GetTemporary(width, height, 0, format);

        Graphics.Blit(source, currentDestination, m_Bloom, BoxDownPrefilterPass);
        RenderTexture currentSource = currentDestination;

        // 盒式采样

        int i = 1;

        // 多次下采样
        for (; i < iteration; i++)
        {
            width /= 2;
            height /= 2;
            if (height < 2)
            {
                break;
            }
            currentDestination = textures[i] =
                RenderTexture.GetTemporary(width, height, 0, format);

            // 下采样
            Graphics.Blit(currentSource, currentDestination, m_Bloom, BoxDownPass);
            currentSource = currentDestination;
        }


        // 多次下采样
        for (i -= 1; i >= 0; i--)
        {
            currentDestination = textures[i];
            textures[i] = null;

            // 上采样
            Graphics.Blit(currentSource, currentDestination, m_Bloom, BoxUpPass);
            RenderTexture.ReleaseTemporary(currentSource);
            currentSource = currentDestination;
        }

        // 最后一遍 原图与bloom混合 
        m_Bloom.SetTexture("_SourceTex", source);
        Graphics.Blit(currentSource, destination, m_Bloom, ApplyBloomPass);
        RenderTexture.ReleaseTemporary(currentSource);

        RenderTexture.ReleaseTemporary(currentSource);
    }
}
