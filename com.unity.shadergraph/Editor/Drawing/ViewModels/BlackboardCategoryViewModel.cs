using System;
using System.Collections.Generic;
using UnityEngine.UIElements;

namespace UnityEditor.ShaderGraph.Drawing
{
    class BlackboardCategoryViewModel : ISGViewModel
    {
        public VisualElement parentView { get; set; }
        internal string name { get; set; }
        internal string associatedCategoryID { get; set; }
        internal bool isExpanded { get; set; }
        internal Action<IGraphDataAction> requestModelChangeAction { get; set; }

        // Wipes all data in this view-model
        public void ResetViewModelData()
        {
            name = String.Empty;
            associatedCategoryID = string.Empty;
            isExpanded = false;
            requestModelChangeAction = null;
        }
    }
}
