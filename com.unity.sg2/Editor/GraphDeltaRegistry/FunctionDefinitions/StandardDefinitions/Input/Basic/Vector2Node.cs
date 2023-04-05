using Usage = UnityEditor.ShaderGraph.GraphDelta.GraphType.Usage;

namespace UnityEditor.ShaderGraph.Defs
{

    internal class Vector2Node : IStandardNode
    {
        public static string Name => "Vector2";
        public static int Version => 1;

        public static FunctionDescriptor FunctionDescriptor => new(
            Name,
            "    Out = X;",
            new ParameterDescriptor[]
            {
                new ParameterDescriptor("X", TYPE.Vec2, Usage.Static),
                new ParameterDescriptor("Out", TYPE.Vec2, Usage.Out)
            }
        );

        public static NodeUIDescriptor NodeUIDescriptor => new(
            Version,
            Name,
            displayName: "Vector 2",
            tooltip: "Creates a user-defined value with 2 channels.",
            category: "Input/Basic",
            synonyms: new string[4] { "2", "v2", "vec2", "float2" },
            description: "pkg://Documentation~/previews/Vector2.md",
            parameters: new ParameterUIDescriptor[2] {
                new ParameterUIDescriptor(
                    name: "X",
                    displayName: string.Empty,
                    tooltip: "a user-defined value with 2 channels"
                ),
                new ParameterUIDescriptor(
                    name: "Out",
                    displayName: string.Empty,
                    tooltip: "a user-defined value with 2 channels"
                )
            }
        );
    }
}
