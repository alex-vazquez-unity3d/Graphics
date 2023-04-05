using Usage = UnityEditor.ShaderGraph.GraphDelta.GraphType.Usage;

namespace UnityEditor.ShaderGraph.Defs
{

    internal class Vector3Node : IStandardNode
    {
        public static string Name => "Vector3";
        public static int Version => 1;

        public static FunctionDescriptor FunctionDescriptor => new(
            Name,
            "    Out = X;",
            new ParameterDescriptor[]
            {
                new ParameterDescriptor("X", TYPE.Vec3, Usage.Static),
                new ParameterDescriptor("Out", TYPE.Vec3, Usage.Out)
            }
        );

        public static NodeUIDescriptor NodeUIDescriptor => new(
            Version,
            Name,
            displayName: "Vector 3",
            tooltip: "Creates a user-defined value with 3 channels.",
            category: "Input/Basic",
            synonyms: new string[4] { "3", "v3", "vec3", "float3" },
            description: "pkg://Documentation~/previews/Vector3.md",
            parameters: new ParameterUIDescriptor[2] {
                new ParameterUIDescriptor(
                    name: "X",
                    displayName: string.Empty,
                    tooltip: "a user-defined value with 3 channels"
                ),
                new ParameterUIDescriptor(
                    name: "Out",
                    displayName: string.Empty,
                    tooltip: "a user-defined value with 3 channels"
                )
            }
        );
    }
}
