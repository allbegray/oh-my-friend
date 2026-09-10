import SceneKit

/// 마인크래프트 원작 인챈트 보라색 일렁임(Enchantment Glint) 쉐이더
public struct EnchantmentGlintShader {
    public static let glintModifier = """
    // Minecraft Enchantment Glint (보라색 일렁이는 마법 광택)
    float2 uv = _surface.diffuseTexcoord;
    float time = u_time * 1.6;
    float diag1 = sin((uv.x + uv.y) * 14.0 + time) * 0.5 + 0.5;
    float diag2 = sin((uv.x - uv.y) * 9.0 - time * 0.9) * 0.5 + 0.5;
    float glint = pow(diag1 * diag2, 2.0) * 0.95;
    float3 glintColor = float3(0.72, 0.18, 0.98); // 마인크래프트 인챈트 보라색
    _surface.emission.rgb += glintColor * glint;
    """

    public static func apply(to node: SCNNode, enabled: Bool) {
        let modifier = enabled ? [SCNShaderModifierEntryPoint.surface: glintModifier] : nil

        func recurse(n: SCNNode) {
            n.geometry?.materials.forEach { mat in
                mat.shaderModifiers = modifier
            }
            n.childNodes.forEach { recurse(n: $0) }
        }
        recurse(n: node)
    }
}
