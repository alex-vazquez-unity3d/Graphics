using System;
using System.Diagnostics.CodeAnalysis;
using System.IO;
using System.Xml;
using JetBrains.Annotations;
using Microsoft.CodeAnalysis.CSharp;

namespace UnityEngine.Rendering.UIGen
{
    public class UIImplementationDocuments
    {
        public static bool From(
            [DisallowNull] string identifier,
            [DisallowNull] XmlDocument visualTree,
            [DisallowNull] CSharpSyntaxTree runtimeCode,
            [NotNullWhen(true)] out UIImplementationDocuments documents,
            [NotNullWhen(false)] out Exception error
        )
        {
            documents = new UIImplementationDocuments(identifier, visualTree, runtimeCode);
            error = default;
            return true;
        }

        string m_Identifier;
        XmlDocument m_Uxml;
        CSharpSyntaxTree m_RuntimeCode;

        UIImplementationDocuments(
            [DisallowNull] string identifier,
            [DisallowNull] XmlDocument uxml,
            [DisallowNull] CSharpSyntaxTree runtimeCode
        )
        {
            m_Identifier = identifier;
            m_Uxml = uxml;
            m_RuntimeCode = runtimeCode;
        }

        // Consider async API?
        [MustUseReturnValue]
        public bool WriteToDisk(
            GenerationTargetLocations locations,
            [NotNullWhen(false)] out Exception error
        )
        {
            if (!locations.GetAssetPathFor($"{m_Identifier}.uxml", out var uxmlPath, out error))
                return false;
            if (!locations.GetRuntimeCodePathFor($"{m_Identifier}.cs", out var runtimeCodePath, out error))
                return false;

            try
            {
                File.WriteAllText(uxmlPath, m_Uxml.OuterXml);
                File.WriteAllText(runtimeCodePath, m_RuntimeCode.ToString());
            }
            catch (Exception e)
            {
                error = e;
                return false;
            }
            return true;
        }
    }
}
