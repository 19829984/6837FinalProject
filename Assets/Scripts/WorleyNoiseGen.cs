using System;
using System.Collections;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;

public class WorleyNoiseGen : MonoBehaviour
{
    // Start is called before the first frame update
    public int WorleyResolutionLv1 = 1;
    public int WorleyResolutionLv2 = 1;
    public int WorleyResolutionLv3 = 1;

    public ComputeShader worleyCompute;

    public Shader test_shader;

    [Range(-2, 2)]
    public float frequency;
    public Vector3 offset;
    public Vector3 scale;

    readonly int resolution = 256;
    private RenderTexture rt;
    private System.Random prng = new System.Random();
    private int TextureSize;
    private int numThreadGroups;

    private Vector3[] worley_points_lv1;
    private Vector3[] worley_points_lv2;
    private Vector3[] worley_points_lv3;
    public bool showNoiseTex = false;
    public bool generate = true;

    private CloudRenderer cloudRenderer;

    private Material mat;
    void Start()
    {
        var format = UnityEngine.Experimental.Rendering.GraphicsFormat.R16G16B16A16_UNorm;
        rt = new RenderTexture(resolution, resolution, 0);
        rt.graphicsFormat = format;
        rt.enableRandomWrite = true;
        rt.useMipMap = false;
        rt.volumeDepth = resolution;
        rt.dimension = UnityEngine.Rendering.TextureDimension.Tex3D;
        rt.wrapMode = TextureWrapMode.Repeat;
        rt.filterMode = FilterMode.Bilinear;
        rt.Create();

        TextureSize = rt.width;
        numThreadGroups = Mathf.CeilToInt(TextureSize / 8f);
        worley_points_lv1 = CreateWorleyPoints(prng, WorleyResolutionLv1);
        worley_points_lv2 = CreateWorleyPoints(prng, WorleyResolutionLv2);
        worley_points_lv3 = CreateWorleyPoints(prng, WorleyResolutionLv3);
        cloudRenderer = GetComponent<CloudRenderer>();
        GenWorley();
    }

    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        if(generate) GenWorley();
        
        if (!showNoiseTex) {
            Graphics.Blit(source, destination);
            return;
        }
        
        
        mat.SetTexture("_NoiseTex", rt);
        mat.SetVector("_sample_offset", offset);
        mat.SetVector("_scale", scale);
        Graphics.Blit(source, destination, mat);
    }

    void GenWorley(){
        if (mat == null)
        {
            mat = new Material(test_shader);
        }
        
        var worley_buffer_lv1 = new ComputeBuffer(worley_points_lv1.Length, sizeof(float) * 3, ComputeBufferType.Structured);
        worley_buffer_lv1.SetData(worley_points_lv1);

        
        var worley_buffer_lv2 = new ComputeBuffer(worley_points_lv2.Length, sizeof(float) * 3, ComputeBufferType.Structured);
        worley_buffer_lv2.SetData(worley_points_lv2);

        
        var worley_buffer_lv3 = new ComputeBuffer(worley_points_lv3.Length, sizeof(float) * 3, ComputeBufferType.Structured);
        worley_buffer_lv3.SetData(worley_points_lv3);


        var minMaxData = new int[] { int.MaxValue, 0 };
        var minMaxBuffer = new ComputeBuffer(minMaxData.Length, sizeof(int), ComputeBufferType.Structured);
        minMaxBuffer.SetData(minMaxData);

        worleyCompute.SetBuffer(0, "WorleyPointsLv1", worley_buffer_lv1);
        worleyCompute.SetBuffer(0, "WorleyPointsLv2", worley_buffer_lv2);
        worleyCompute.SetBuffer(0, "WorleyPointsLv3", worley_buffer_lv3);
        worleyCompute.SetBuffer(0, "minMaxBuffer", minMaxBuffer);
        worleyCompute.SetInt("numCellsLv1", WorleyResolutionLv1);
        worleyCompute.SetInt("numCellsLv2", WorleyResolutionLv2);
        worleyCompute.SetInt("numCellsLv3", WorleyResolutionLv3);
        worleyCompute.SetInt("resolution", TextureSize);
        worleyCompute.SetFloat("frequency", frequency);
        worleyCompute.SetTexture(0, "Result", rt);
        worleyCompute.Dispatch(0, numThreadGroups, numThreadGroups, numThreadGroups);

        worley_buffer_lv1.Release();
        worley_buffer_lv2.Release();
        worley_buffer_lv3.Release();

        worleyCompute.SetBuffer(1, "minMaxBuffer", minMaxBuffer);
        worleyCompute.SetTexture(1, "Result", rt);
        worleyCompute.Dispatch(1, numThreadGroups, numThreadGroups, numThreadGroups);

        minMaxBuffer.Release();
        cloudRenderer.noiseTexture = rt;
    }

    Vector3[] CreateWorleyPoints(System.Random prng, int numCellsPerAxis)
    {
        var return_points = new Vector3[numCellsPerAxis * numCellsPerAxis * numCellsPerAxis];
        float cellSize = 1f / numCellsPerAxis;
        for (int x = 0; x < numCellsPerAxis; x++)
        {
            for (int y = 0; y < numCellsPerAxis; y++)
            {
                for (int z = 0; z < numCellsPerAxis; z++)
                {
                    float randomX = (float)prng.NextDouble();
                    float randomY = (float)prng.NextDouble();
                    float randomZ = (float)prng.NextDouble();

                    Vector3 randomOffset = new Vector3(randomX, randomY, randomZ) * cellSize;
                    Vector3 cellCorner = new Vector3(x, y, z) * cellSize;

                    int cell_index = x + numCellsPerAxis * (y + numCellsPerAxis * z);
                    return_points[cell_index] = cellCorner + randomOffset;
                }
            }
        }
        return return_points;
    }
}
