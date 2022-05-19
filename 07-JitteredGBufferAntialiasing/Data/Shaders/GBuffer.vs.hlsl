#include "VertexAttrib.h"
__import ShaderCommon;
__import DefaultVS;

VertexOut main(VertexIn vIn) {
	return defaultVS(vIn);
}
