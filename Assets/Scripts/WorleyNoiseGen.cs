using System;
using System.Collections;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;

public class WorleyNoiseGen : MonoBehaviour
{
    // Start is called before the first frame update
    public int WorleyResolution = 1;

    public ComputeShader worleyCompute;

    public Shader test_shader;

    public float depth;

    readonly int resolution = 256;
    private RenderTexture rt;
    private System.Random prng = new System.Random();
    private int TextureSize;
    private int numThreadGroups;

    private Material mat;
    void Start()
    {
        var format = UnityEngine.Experimental.Rendering.GraphicsFormat.R16G16B16A16_UNorm;
        rt = new RenderTexture(resolution, resolution, 0);
        rt.graphicsFormat = format;
        rt.enableRandomWrite = true;
        rt.volumeDepth = resolution;
        rt.dimension = UnityEngine.Rendering.TextureDimension.Tex3D;
        rt.wrapMode = TextureWrapMode.Repeat;
        rt.filterMode = FilterMode.Bilinear;
        rt.Create();

        TextureSize = rt.width;
        numThreadGroups = Mathf.CeilToInt(TextureSize / 8f);

        var worley_points = CreateWorleyPoints(prng, WorleyResolution);
        var buffer = new ComputeBuffer(worley_points.Length, sizeof(float) * 3, ComputeBufferType.Structured);
        buffer.SetData(worley_points);

        worleyCompute.SetBuffer(0, "WorleyPoints", buffer);
        worleyCompute.SetInt("resolution", TextureSize);
        worleyCompute.SetInt("numCells", WorleyResolution);
        worleyCompute.SetTexture(0, "Result", rt);
        worleyCompute.Dispatch(0, numThreadGroups, numThreadGroups, numThreadGroups);

        buffer.Release();
    }

    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        if (mat == null)
        {
            mat = new Material(test_shader);
        }
        mat.SetTexture("_NoiseTex", rt);
        mat.SetFloat("_depth_lv", depth);
        Graphics.Blit(source, destination, mat);
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
