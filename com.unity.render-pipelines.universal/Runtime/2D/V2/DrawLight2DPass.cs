using System.Collections.Generic;
using UnityEngine.Experimental.Rendering;

namespace UnityEngine.Rendering.Universal
{
    internal class DrawLight2DPass : ScriptableRenderPass, IRenderPass2D
    {
        private static readonly ProfilingSampler m_ProfilingDrawLights = new ProfilingSampler("Draw 2D Lights");
        private static readonly int k_InverseHDREmulationScaleID = Shader.PropertyToID("_InverseHDREmulationScale");
        public static readonly string[] k_WriteBlendStyleKeywords =
        {
            "WRITE_SHAPE_LIGHT_TYPE_0", "WRITE_SHAPE_LIGHT_TYPE_1", "WRITE_SHAPE_LIGHT_TYPE_2", "WRITE_SHAPE_LIGHT_TYPE_3"
        };

        private LayerBatch m_LayerBatch;
        private UniversalRenderer2D.GBuffers m_GBuffers;

        public DrawLight2DPass(Renderer2DData data, LayerBatch layerBatch, UniversalRenderer2D.GBuffers buffers)
        {
            m_LayerBatch = layerBatch;
            m_GBuffers = buffers;
            rendererData = data;
            useNativeRenderPass = true;
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            var cmd = CommandBufferPool.Get();
            using (new ProfilingScope(cmd, m_ProfilingDrawLights))
            {
                cmd.SetGlobalFloat(k_InverseHDREmulationScaleID, 1.0f / rendererData.hdrEmulationScale);
                if (useNativeRenderPass)
                    cmd.EnableShaderKeyword("_RENDER_PASS_ENABLED");

                for (var blendStyleIndex = 0; blendStyleIndex < 4; blendStyleIndex++)
                {
                    var visibleLights = m_LayerBatch.GetLights(blendStyleIndex);
                    if (visibleLights.Count == 0)
                        continue;

                    cmd.EnableShaderKeyword(k_WriteBlendStyleKeywords[blendStyleIndex]);

                    foreach (var light in visibleLights)
                    {
                        var lightMaterial = rendererData.GetLightMaterial(light, false);
                        RendererLighting.SetGeneralLightShaderGlobals(this, cmd, light);

                        if (light.normalMapQuality != Light2D.NormalMapQuality.Disabled ||
                            light.lightType == Light2D.LightType.Point)
                            RendererLighting.SetPointLightShaderGlobals(this, cmd, light);

                        if (light.lightType == Light2D.LightType.Point)
                        {
                            RendererLighting.DrawPointLight(cmd, light, light.lightMesh, lightMaterial);
                        }
                        else
                        {
                            cmd.DrawMesh(light.lightMesh, light.transform.localToWorldMatrix, lightMaterial);
                        }
                    }

                    cmd.DisableShaderKeyword(k_WriteBlendStyleKeywords[blendStyleIndex]);
                }
            }
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

        public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
        {
            // ConfigureInputAttachments(new []{gbuffers[4]}, new []{false});
            ConfigureInputAttachments(m_GBuffers.buffers[4], true);

            var rt = new RTHandle[4];
            var ft = new GraphicsFormat[rt.Length];

            for (var i = 0; i < rt.Length; i++)
            {
                rt[i] = m_GBuffers.buffers[i];
                ft[i] = m_GBuffers.formats[i];
            }

            ConfigureTarget(rt, m_GBuffers.depthAttachment, ft);
            ConfigureClear(ClearFlag.None, Color.black);
        }

        public Renderer2DData rendererData { get; }
    }
}
