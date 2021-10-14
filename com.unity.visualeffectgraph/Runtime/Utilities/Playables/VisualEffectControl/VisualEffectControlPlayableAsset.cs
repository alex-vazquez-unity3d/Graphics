#if VFX_HAS_TIMELINE
using System;
using System.Linq;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Playables;
using UnityEngine.Timeline;

namespace UnityEngine.VFX
{
    // Represents the serialized data for a clip on the TextTrack
    [Serializable]
    public class VisualEffectControlPlayableAsset : PlayableAsset, ITimelineClipAsset
    {
        //[NoFoldOut]
        [NotKeyable] // NotKeyable used to prevent Timeline from making fields available for animation.
        public VisualEffectControlPlayableBehaviour template = new VisualEffectControlPlayableBehaviour();

        public static bool useBlending_WIP
        {
            get
            {
#if UNITY_EDITOR
                return UnityEditor.EditorPrefs.GetBool("VFX.MixerUseBlending_TEMP_TO_BE_REMOVED", true);
#else
                return true;
#endif
            }
        }

        public ClipCaps clipCaps
        {
            get { return useBlending_WIP ? ClipCaps.Blending : ClipCaps.None; }
        }

        public double clipStart { get; set; }
        public double clipEnd { get; set; }

        public void SetDefaultEvent(double playAfterClipStart, double stopBeforeClipEnd)
        {
            var previousEvent = events == null ? new List<VisualEffectPlayableSerializedEvent>() : events.ToList();
            events = new List<VisualEffectPlayableSerializedEvent>();

            int indexOfStart = -1;
            int indexOfStop = -1;

            for (int i = 0; i < previousEvent.Count; ++i)
            {
                if (indexOfStart == -1 && previousEvent[i].type == VisualEffectPlayableSerializedEvent.Type.Play)
                    indexOfStart = i;
                if (indexOfStop == -1 && previousEvent[i].type == VisualEffectPlayableSerializedEvent.Type.Stop)
                    indexOfStop = i;
                if (indexOfStop != -1 && indexOfStart != -1)
                    break;
            }

            //Copy Play
            {
                var startName = indexOfStart == -1 ? VisualEffectAsset.PlayEventName : previousEvent[indexOfStart].name;
                var startTime = playAfterClipStart;

                if (!useBlending_WIP && indexOfStart != -1)
                    startTime = previousEvent[indexOfStart].time;

                events.Add(new VisualEffectPlayableSerializedEvent()
                {
                    name = startName,
                    time = startTime,
                    timeSpace = VisualEffectPlayableSerializedEvent.TimeSpace.AfterClipStart,
                    type = VisualEffectPlayableSerializedEvent.Type.Play
                });
            }

            //Copy Stop
            {
                var stopName = indexOfStop == -1 ? VisualEffectAsset.StopEventName : previousEvent[indexOfStop].name;
                var stopTime = stopBeforeClipEnd;

                if (!useBlending_WIP && indexOfStop != -1)
                    stopTime = previousEvent[indexOfStop].time;

                events.Add(new VisualEffectPlayableSerializedEvent()
                {
                    name = stopName,
                    time = stopTime,
                    timeSpace = VisualEffectPlayableSerializedEvent.TimeSpace.BeforeClipEnd,
                    type = VisualEffectPlayableSerializedEvent.Type.Stop
                });
            }

            if (indexOfStop != -1)
                previousEvent.RemoveAt(indexOfStop);

            if (indexOfStart != -1)
                previousEvent.RemoveAt(indexOfStart);

            //Take the rest
            var other = previousEvent.Select(o =>
            {
                return new VisualEffectPlayableSerializedEvent()
                {
                    name = o.name,
                    time = o.time,
                    timeSpace = o.timeSpace,
                    type = VisualEffectPlayableSerializedEvent.Type.Custom
                };
            }).ToArray();
            events.AddRange(other);
        }

        [NotKeyable]
        public List<VisualEffectPlayableSerializedEvent> events;

        public override Playable CreatePlayable(PlayableGraph graph, GameObject owner)
        {
            var playable = ScriptPlayable<VisualEffectControlPlayableBehaviour>.Create(graph, template);
            var behaviour = playable.GetBehaviour();
            behaviour.clipStart = clipStart;
            behaviour.clipEnd = clipEnd;
            behaviour.events = events.ToArray();
            return playable;
        }
    }
}
#endif
