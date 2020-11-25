using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode, ImageEffectAllowedInSceneView]
public class CloudRenderer : MonoBehaviour
{
    // Raymarch parameters
    [Range(0.001f, 0.2f)]
    public float stepSize = 0.1f;
    
    public Transform cloudContainer;
    public Shader cloudShader;
    public Texture3D noiseTexture;
    Material cloudMaterial;

    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        Vector3 containerOffset = cloudContainer.localScale * .5f;
        Vector3
            containerMin = cloudContainer.position - containerOffset,
            containerMax = cloudContainer.position + containerOffset;
        cloudMaterial.SetVector("_ContainerMin", containerMin);
        cloudMaterial.SetVector("_ContainerMax", containerMax);


        // Noise Textures
        cloudMaterial.SetTexture("_NoiseTexture", noiseTexture);
        
        // Raymarch parameters
        cloudMaterial.SetFloat("_StepSize", stepSize);

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
