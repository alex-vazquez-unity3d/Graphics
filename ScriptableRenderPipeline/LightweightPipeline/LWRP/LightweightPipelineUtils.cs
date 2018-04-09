using System;
using System.Collections.Generic;

namespace UnityEngine.Experimental.Rendering.LightweightPipeline
{
    public class CameraComparer : IComparer<Camera>
    {
        public int Compare(Camera lhs, Camera rhs)
        {
            return (int)(lhs.depth - rhs.depth);
        }
    }

    [Flags]
    public enum FrameRenderingConfiguration
    {
        None = 0,
        Stereo = (1 << 0),
        Msaa = (1 << 1),
        BeforeTransparentPostProcess = (1 << 2),
        PostProcess = (1 << 3),
        DepthPrePass = (1 << 4),
        DepthCopy = (1 << 5),
        DefaultViewport = (1 << 6),
        IntermediateTexture = (1 << 7)
    }

    public static class LightweightUtils
    {
        public static void StartStereoRendering(Camera camera, ref ScriptableRenderContext context, FrameRenderingConfiguration renderingConfiguration)
        {
            if (HasFlag(renderingConfiguration, FrameRenderingConfiguration.Stereo))
                context.StartMultiEye(camera);
        }

        public static void StopStereoRendering(Camera camera, ref ScriptableRenderContext context, FrameRenderingConfiguration renderingConfiguration)
        {
            if (HasFlag(renderingConfiguration, FrameRenderingConfiguration.Stereo))
                context.StopMultiEye(camera);
        }

        public static void GetLightCookieMatrix(VisibleLight light, out Matrix4x4 cookieMatrix)
        {
            cookieMatrix = Matrix4x4.Inverse(light.localToWorld);

            if (light.lightType == LightType.Directional)
            {
                float scale = 1.0f / light.light.cookieSize;

                // apply cookie scale and offset by 0.5 to convert from [-0.5, 0.5] to texture space [0, 1]
                Vector4 row0 = cookieMatrix.GetRow(0);
                Vector4 row1 = cookieMatrix.GetRow(1);
                cookieMatrix.SetRow(0, new Vector4(row0.x * scale, row0.y * scale, row0.z * scale, row0.w * scale + 0.5f));
                cookieMatrix.SetRow(1, new Vector4(row1.x * scale, row1.y * scale, row1.z * scale, row1.w * scale + 0.5f));
            }
            else if (light.lightType == LightType.Spot)
            {
                // we want out.w = 2.0 * in.z / m_CotanHalfSpotAngle
                // c = cotHalfSpotAngle
                // 1 0 0 0
                // 0 1 0 0
                // 0 0 1 0
                // 0 0 2/c 0
                // the "2" will be used to scale .xy for the cookie as in .xy/2 + 0.5
                float scale = 1.0f / light.range;
                float halfSpotAngleRad = Mathf.Deg2Rad * light.spotAngle * 0.5f;
                float cs = Mathf.Cos(halfSpotAngleRad);
                float ss = Mathf.Sin(halfSpotAngleRad);
                float cotHalfSpotAngle = cs / ss;

                Matrix4x4 scaleMatrix = Matrix4x4.identity;
                scaleMatrix.m00 = scaleMatrix.m11 = scaleMatrix.m22 = scale;
                scaleMatrix.m33 = 0.0f;
                scaleMatrix.m32 = scale * (2.0f / cotHalfSpotAngle);

                cookieMatrix = scaleMatrix * cookieMatrix;
            }

            // Remaining light types don't support cookies
        }

        public static bool IsSupportedShadowType(LightType lightType)
        {
            return lightType == LightType.Directional || lightType == LightType.Spot;
        }

        public static bool IsSupportedCookieType(LightType lightType)
        {
            return lightType == LightType.Directional || lightType == LightType.Spot;
        }

        public static bool PlatformSupportsMSAABackBuffer()
        {
#if UNITY_ANDROID || UNITY_IPHONE || UNITY_TVOS || UNITY_SAMSUNGTV
            return true;
#else
            return false;
#endif
        }

        public static bool HasFlag(FrameRenderingConfiguration mask, FrameRenderingConfiguration flag)
        {
            return (mask & flag) != 0;
        }

        public static Mesh CreateQuadMesh(bool uvStartsAtTop)
        {
            float topV, bottomV;
            if (uvStartsAtTop)
            {
                topV = 0.0f;
                bottomV = 1.0f;
            }
            else
            {
                topV = 1.0f;
                bottomV = 0.0f;
            }

            Mesh mesh = new Mesh();
            mesh.vertices = new Vector3[]
            {
                new Vector3(-1.0f, -1.0f, 0.0f),
                new Vector3(-1.0f,  1.0f, 0.0f),
                new Vector3(1.0f, -1.0f, 0.0f),
                new Vector3(1.0f,  1.0f, 0.0f)
            };

            mesh.uv = new Vector2[]
            {
                new Vector2(0.0f, bottomV),
                new Vector2(0.0f, topV),
                new Vector2(1.0f, bottomV),
                new Vector2(1.0f, topV)
            };

            mesh.triangles = new int[] { 0, 1, 2, 2, 1, 3 };
            return mesh;
        }
    }
}
