# Unity Baked Volumetrics
A graphics solution for completely baked volumetric lighting, meant to be very lightweight and inexpensive for VR *(and non-vr)*. 

# VRC Light Volumes
I added a new version of the shader for [VRC Light Volumes](https://github.com/REDSIM/VRCLightVolumes/)

## How to use in VRC:
- Download this UnityPackage : [DOWNLOAD](https://github.com/Ikeiwa/Unity-Baked-Volumetrics/raw/refs/heads/main/GithubContent/VRC_Volumetric_Fog.unitypackage)
- Grab the "VolumetricFog" in "BakedVolumetrics/VRC" and place it in the scene.
- Scale and move the volume to fit your scene or the area you want fog in
- Done

## Important! 
You need to enable the depth texture on the camera, you can use Varneon [Depth Buffer Toolkit](https://github.com/Varneon/VUdon-DepthBufferToolkit) or if you use SDK 3.8.1 and up you can use `VRCCameraSettings.ScreenCamera.DepthTextureMode = DepthTextureMode.Depth` in a script

# Results
![sponza1](GithubContent/sponza1.jpg)

![sponza2](GithubContent/sponza2.png)

![sponza3](GithubContent/sponza3.png)

![industrial1](GithubContent/industrial1.png)

![yakohama1](GithubContent/yakohama1.png)

![yakohama2](GithubContent/yakohama2.png)

![yakohama3](GithubContent/yakohama3.jpg)

![church1](GithubContent/church1.png)

![church2](GithubContent/church2.png)

# Features

TLDR: This is basically lightmapping but for volumetric fog. 

- Completely baked volumetric lighting designed to be lightweight and fast at runtime, and it's baked completely offline in-editor.
- Volumetric lighting can be generated from multiple sources. *(Light Probes, Light Probe Proxy Volumes, Voxel Tracer)* 
- Density is baked into the 3d texture *(RGB: Color A: Density)* and different density types can be used for different looks. *(Constant, Luminance Based, Height Based, Luminance Height Based)*
- Post Adjustments can be applied to tweak and improve the look of the generated volume such as Seperable 3D Gaussian Blur for improved quality/smoothness, and more artistic controls like Brightness, Contrast, Saturation, Vibrance, Hue Shift, Gamma, Color Filter, Color Multiplication.
- Multiple versions of the same effect to suit different needs... (A scene-based version, and multiple post-process versions)

**NOTE: Constructed on the Built-In Rendering Pipeline (But can be adapted to work with other SRPs).**

# Information

## How it works

To start you define a box volume within your scene, the setting where it is located, and its bounds. The resolution of the 3D texture is computed by determining the size of the individual voxels *(You can also set a custom resolution by hand)*. Next you can choose to either sample lighting from the scene light probes, light probe proxy volumes, or a voxel tracer. After that, there is an option to set the fog density of the volume *(constant, luminance, height-based, etc.)* The next step is to generate a 3D texture that is saved into the disk. 

For the shader, what we do is sample that 3D texture and perform a raymarch through it, checking it against the scene depth buffer. The ray terminates if: it intersects with the scene, is out of bounds, or if the density is too thick. While raymarching also we jitter the samples to improve the quality. The final result is then lerped with the scene color buffer based on transmittance.

## Multiple Implementations

There are 2 versions of this effect, two being a typical **Post Process** version, and the other is a **Scene Based solution** solution...

### Post Processing V1
This is the first implementation of the effect implemented as a post-process. It does exactly as described in the **How it works** section.

### Post Processing V2
This is similar to **Post Processing V2**, but an optimization was added to where the volumetrics are rendered at half resolution and upsampled.

### Scene Based
The first implementation of the effect is a scene-based effect. This is for circumstances where you can't create custom post-processing effects. Why the heck would this be the case? A good example of this scenario is VRChat where you can't make custom post-processing effects, but you can still make shaders within the scene itself. 

This REQUIRES camera depth generation enabled. This works automatically for deferred rendering, but not for forward rendering by default. You can enable it by using C# scripting. However, if you don't have access to the main camera properties there are other ways of enabling it.

***Camera Depth Texture Trick 1:*** If the post-processing stack is available, you can enable ambient occlusion which will enable the camera depth texture generation flag. *(For a low overhead put the AO quality settings at its lowest if you don't intend to use it. The intensity value also needs to be greater than 0 otherwise the effect won't be active)*

***Camera Depth Texture Trick 2:***  Courtesy of [orels1](https://github.com/orels1), Create a directional light, that casts shadows. Set the culling layer on that directional light to hit a specific layer which will cause unity to enable camera depth texture generation.

*Will be elaborated on but this has been tested and works on Oculus/Meta Quest 2.*

## Advantages/Drawbacks

### Advantages

- Simple and performant, at runtime a 3D texture is sampled and raymarched against the scene depth buffer. No additional steps are done (compared to other volumetric lighting solutions which have to sample of lights, shadowmaps, etc.).
- The look of the volumetrics is generated purely offline. With the nature of it being offline, you can apply a lot more computation and processing to sample things like indirect lighting which completely transforms the look of the fog.

### Drawbacks

- High-resolution 3D textures can eat up VRAM and disk space easily, so to keep it small they have to be low resolution which isn't good for crisp shadows.
- This implementation is completely baked, meaning any runtime lights will not change or affect the look of the fog.
- If you are sampling from light probes only, the clarity/precision/resolution of your volume depends on how densely populated your light probe grid is. If it's very sparse then your volume will look very low resolution (even if you are using a high-resolution 3D texture) because there are not enough light probes to sample from *(NOTE: To combat that, you can use the voxel tracer instead)*.
- For the Post Processing V1/V2 implementations you cannot stack multiple volumes. (This should be solved in the future with a newer implementation that utilizes a froxel)
- For Post Processing V1/V2 and Scene Based implementations, low raymarch samples (or high raymarch distances) can lead to very noisy results.
- For the scene-based variant that samples lighting from a Light Probe Proxy Volume, there is no pre-processing that can be done to filter the volume at runtime efficiently so if the LPPV is at a low resolution the results can look very blocky/coarse.

## Future Plans/Ideas

- **POST PROCESSING:** interleaved rendering.
- **POST PROCESSING:** temporal filtering in conjunction with animated noise to accumulate samples over multiple frames.
- **POST PROCESSING:** froxel solution to intersect multiple volumes in a scene, so we can raymarch only once rather than raymarch for each volume in the scene which would be dumb. This also allows the ability to have multiple volumes in the scene in an efficient way for the post-processing solution.
- **EDITOR:** Previewing Voxels is really really slow at low-density values, need to come up with a different way to preview the different voxels.
- **EDITOR:** Add a context menu item in the scene hierarchy to create a volume.

### Credits

- **[orels1](https://github.com/orels1)**: Improved VRC support.
- **[s-ilent](https://github.com/s-ilent)**: Improved noise by utilizing bluenoise on their [fork of this repo](https://github.com/s-ilent/Unity-Baked-Volumetrics).
- **[Christoph Peters](http://momentsingraphics.de/BlueNoise.html)**: Free blue noise textures.
- **[pema99](https://gist.github.com/pema99)**: [Quad Intrinsics](https://gist.github.com/pema99/9585ca31e31ea8b5bd630171d76b6f3a) library which allows room for additional optimizations.
- **[Voxel Tracer](https://github.com/frostbone25/Unity-Voxel-Tracer)**: My Voxel Tracer.

