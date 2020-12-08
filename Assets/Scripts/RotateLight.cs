using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class RotateLight : MonoBehaviour
{
    public float speed = 1;
    public float swingAngle = 30;

    // Update is called once per frame
    void Update()
    {
        transform.rotation = Quaternion.Euler(new Vector3(Mathf.Sin(Time.fixedTime * speed) * swingAngle + 90, 0, 0));
    }
}
