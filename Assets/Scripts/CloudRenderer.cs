using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode, ImageEffectAllowedInSceneView]
public class CloudRenderer : MonoBehaviour
{
    // Raymarch parameters
    
    public float stepSize = 0.1f;

    public Transform cloudContainer;
    public Shader cloudShader;
    public Texture2D blueNoise;
    public float blueNoiseStrength;
    [HideInInspector]
    public RenderTexture noiseTexture;
    //public Vector3 noiseScale = Vector3.one;
    public float noiseScale = 1;
    public Vector3 cloudMovement;
    [Range(0, 1)]
    public float densityBias = 0;
    public float densityMultiplier = 1;
    public int NumLightSteps = 1;
    public float DarknessThreshold = 0;
    public Color lightColor = new Color(1,1,1);
    public float lightAbsorption = 1;
    public float BeerPowderScaler = 2;
    public float BeerPowderPower = 2;
    public float rainAbsorption = 1;
    public Vector4 phase;

    Material cloudMaterial;

    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        stepSize = Mathf.Max(0.05f, stepSize);
        Camera.current.depthTextureMode = DepthTextureMode.Depth;
        if (cloudMaterial == null)
            cloudMaterial = new Material(cloudShader);
        Vector3 containerOffset = cloudContainer.localScale * .5f;
        Vector3
            containerMin = cloudContainer.position - containerOffset,
            containerMax = cloudContainer.position + containerOffset;
        cloudMaterial.SetVector("_ContainerMin", containerMin);
        cloudMaterial.SetVector("_ContainerMax", containerMax);

        // Noise Textures
        cloudMaterial.SetTexture("_NoiseTexture", noiseTexture);
        cloudMaterial.SetVector("_NoiseScale", new Vector3(noiseScale, noiseScale, noiseScale)/100);
        cloudMaterial.SetVector("_NoiseOffset", (cloudMovement * (Time.fixedTime%100)) / 100);
        cloudMaterial.SetFloat("_DensityBias", densityBias);
        cloudMaterial.SetFloat("_DensityMultiplier", densityMultiplier);
        cloudMaterial.SetTexture("_BlueNoise", blueNoise);
        cloudMaterial.SetFloat("_BlueNoiseStrength", blueNoiseStrength);

        // Raymarch parameters
        cloudMaterial.SetFloat("_StepSize", stepSize);

        // Light parameters
        cloudMaterial.SetInt("_NumLightSteps", NumLightSteps);
        cloudMaterial.SetFloat("_DarknessThreshold", DarknessThreshold);
        cloudMaterial.SetFloat("_BeerPowderScaler", BeerPowderScaler);
        cloudMaterial.SetFloat("_BeerPowderPower", BeerPowderPower);
        cloudMaterial.SetFloat("_RainAbsorption", rainAbsorption);

        //Others
        cloudMaterial.SetVector("_LightColor", lightColor);
        cloudMaterial.SetFloat("_LightAbsorption", lightAbsorption);
        cloudMaterial.SetVector("_PhaseParams", phase);

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
