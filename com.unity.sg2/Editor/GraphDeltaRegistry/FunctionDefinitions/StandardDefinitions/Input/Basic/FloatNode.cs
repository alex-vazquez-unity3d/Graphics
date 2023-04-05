using Usage = UnityEditor.ShaderGraph.GraphDelta.GraphType.Usage;

namespace UnityEditor.ShaderGraph.Defs
{

    internal class FloatNode : IStandardNode
    {
        public static string Name => "Float";
        public static int Version => 1;

        public static FunctionDescriptor FunctionDescriptor => new(
            Name,
            "    Out = X;",
            new ParameterDescriptor[]
            {
                new ParameterDescriptor("X", TYPE.Float, Usage.Static),
                new ParameterDescriptor("Out", TYPE.Float, Usage.Out)
            }
        );

        public static NodeUIDescriptor NodeUIDescriptor => new(
            Version,
            Name,
            displayName: "Float",
            tooltip: "Creates a user-defined value with 1 channel.",
            category: "Input/Basic",
            synonyms: new string[3] { "1", "v1", "vec1" },
            description: "pkg://Documentation~/previews/Float.md",
            parameters: new ParameterUIDescriptor[2] {
                new ParameterUIDescriptor(
                    name: "X",
                    displayName: string.Empty,
                    tooltip: "the input value"
                ),
                new ParameterUIDescriptor(
                    name: "Out",
                    displayName: string.Empty,
                    tooltip: "a user-defined value with 1 channel"
                )
            }
        );
    }
}
