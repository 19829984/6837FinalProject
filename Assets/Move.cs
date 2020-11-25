using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Move : MonoBehaviour
{
    public float speed = 3.5f;
    private float X;
    private float Y;
    // Update is called once per frame
    void Update()
    {   
        if(Input.GetMouseButton(0)) {
             transform.Rotate(new Vector3(Input.GetAxis("Mouse Y") * speed, -Input.GetAxis("Mouse X") * speed, 0));
             X   = transform.rotation.eulerAngles.x;
             Y = transform.rotation.eulerAngles.y;
             transform.rotation = Quaternion.Euler(X, Y, 0);
         }
        float xAxisValue = Input.GetAxis("Horizontal");
        float zAxisValue = Input.GetAxis("Vertical");
        transform.Translate(new Vector3(xAxisValue, 0.0f, zAxisValue));
    }
}
