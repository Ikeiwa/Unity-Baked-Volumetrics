
using System;
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon;

[RequireComponent(typeof(MeshRenderer))]
[UdonBehaviourSyncMode(BehaviourSyncMode.None)]
[ExecuteAlways]
#if UDONSHARP
public class VRCFogVolume : UdonSharpBehaviour
#else
public class VRCFogVolume : MonoBehaviour
#endif
{
    [SerializeField] private bool continuousUpdate = false;
    
    void Start()
    {
        UpdateVolumeSize();
    }
    
#if UNITY_EDITOR && !COMPILER_UDONSHARP
    private void OnValidate()
    {
        UpdateVolumeSize();
    }
#endif
    
    private void Update()
    {
#if UNITY_EDITOR && !COMPILER_UDONSHARP
        UpdateVolumeSize();
#else
        if(continuousUpdate) UpdateVolumeSize();
#endif
    }

    public void UpdateVolumeSize()
    {
        transform.rotation = Quaternion.identity;
        
        var meshRenderer = GetComponent<MeshRenderer>();

        if (!meshRenderer) return;
        if (!meshRenderer.sharedMaterial || !meshRenderer.sharedMaterial.HasProperty("_VolumeSize")) return;
        
        MaterialPropertyBlock propertyBlock = new MaterialPropertyBlock();
        propertyBlock.SetVector("_VolumeSize", transform.lossyScale);
        meshRenderer.SetPropertyBlock(propertyBlock);
    }
}
