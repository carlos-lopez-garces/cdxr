**CDXR** is my real-time toy renderer. Based on the [Falcor](https://github.com/NVIDIAGameWorks/Falcor) framework and the DirectX Raytracing API, CDXR implements a hybrid rasterization-raytracing configurable pipeline. For writing this renderer, I relied a lot on Chris Wyman's SIGGRAPH courses and the Ray Tracing Gems series.

A more detailed description is found in [my blog](https://carlos-lopez-garces.github.io/projects/cdxr/).

## Features

- One-bounce diffuse global illumination.
- **Deferred rendering via G-Buffer.** 
- Ray-traced ambient occlusion.
- **Denoising and antialiasing via temporal accumulation and camera jittering.**
- Thin lens camera and depth of field. 
- **Tone mapping.** 
- Lambertian diffuse reflection and microfacet reflection models.
- **Unidirectional path tracing.**
- Ashikhmin-Shirley BRDF.

## Select images

<table>
  <tr>
    <td><p align="center">
      <i>Unidirectional path tracing, Ashikhmin-Shirley BRDF. Assets by NVIDIA.</i>
      <img src="/images/12.png">
    </p></td>
    <td><p align="center">
      <i>Unidirectional path tracing, Ashikhmin-Shirley BRDF. Assets by NVIDIA.</i>
      <img src="/images/11.png">
    </p></td>
  </tr>

  <tr>
    <td><p align="center">
      <i>Unidirectional path tracing, combined Lambertian and specular BRDFs, and visibility testing. Assets by NVIDIA.</i>
      <img src="/images/10.png">
    </p></td>
    <td><p align="center">
      <i>Unidirectional path tracing, combined Lambertian and specular BRDFs, and visibility testing. Assets by NVIDIA.</i>
      <img src="/images/9.png">
    </p></td>
  </tr>

  <tr>
    <td><p align="center">
      <i>Direct lighting on a microfacet reflection model. Assets by NVIDIA.</i>
      <img src="/images/8.png">
    </p></td>
    <td><p align="center">
      <i>Direct lighting on a microfacet reflection model. Assets by NVIDIA.</i>
      <img src="/images/6.png">
    </p></td>
  </tr>

  <tr>
    <td><p align="center">
      <i>Direct lighting on a pure Lambertian reflection model. Assets by NVIDIA.</i>
      <img src="/images/7.png">
    </p></td>
    <td><p align="center">
      <i>1-bounce GI and hard shadows. Assets by NVIDIA.</i>
      <img src="/images/5.png">
    </p></td>
  </tr>

  <tr>
    <td><p align="center">
      <i>Occlusion testing with shadow rays, with depth of field. Assets by NVIDIA.</i>
      <img src="/images/3.png">
    </p></td>
    <td><p align="center">
      <i>Occlusion testing with shadow rays, without depth of field. Assets by NVIDIA.</i>
      <img src="/images/4.png">
    </p></td>
  </tr>

  <tr>
    <td><p align="center">
      <i>Lambertian diffuse reflection, with depth of field. Assets by NVIDIA.</i>
      <img src="/images/1.png">
    </p></td>
    <td><p align="center">
      <i>Lambertian diffuse reflection, without depth of field. Assets by NVIDIA.</i>
      <img src="/images/2.png">
    </p></td>
  </tr>
</table>