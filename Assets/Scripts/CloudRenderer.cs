using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode, ImageEffectAllowedInSceneView]
public class CloudRenderer : MonoBehaviour
{

    public Transform cloudContainer;
    public Shader cloudShader;
    Material cloudMaterial;

    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        Vector3 containerOffset = cloudContainer.localScale * .5f;
        Vector3
            containerMin = cloudContainer.position - containerOffset,
            containerMax = cloudContainer.position + containerOffset;
        cloudMaterial.SetVector("_ContainerMin", containerMin);
        cloudMaterial.SetVector("_ContainerMax", containerMax);

        Graphics.Blit(source, destination, cloudMaterial);
        
    }

    // Start is called before the first frame update
    void Start()
    {
        cloudMaterial = new Material(cloudShader);
    }

    // Update is called once per frame
    // void Update()
    // {
        
    // }
}
