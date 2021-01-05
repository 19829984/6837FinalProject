using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

public class CloudUI : MonoBehaviour
{
    public CloudRenderer cr;
    public WorleyNoiseGen wn;

    public Slider bias;
    public Slider worleyFreq;
    public Slider noiseScale;

    public InputField worley_res1, worley_res2, worley_res3;

    // Update is called once per frame
    public void OnEdit()
    {
        cr.densityBias = bias.value;
        cr.noiseScale = noiseScale.value;

        wn.frequency = worleyFreq.value;
        wn.WorleyResolutionLv1 = int.Parse(worley_res1.text);
        wn.WorleyResolutionLv2 = int.Parse(worley_res2.text);
        wn.WorleyResolutionLv3 = int.Parse(worley_res3.text);
    }
}
