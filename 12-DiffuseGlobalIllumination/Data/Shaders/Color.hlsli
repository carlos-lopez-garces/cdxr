// (Relative) luminance Y is luminance normalized to [0.0, 1.0]. The relative luminance of an RGB
// color is a grayscale color and is obtained via dot product with a constant vector that has a
// higher green component because that's the color that the retina perceives the most.
float luminance(float3 rgb) {
	// The sRGB color space is assumed. 
	return dot(rgb, float3(0.2126f, 0.7152f, 0.0722f));
}