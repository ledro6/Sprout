#include <metal_stdlib>
#include <RealityKit/RealityKit.h>

using namespace metal;

// Вода лейки для RealityKit: шейдеры поверхности `CustomMaterial`, считает
// их видеокарта. Геометрию струи строит `Stream` (Views/Water.swift).

// Струя и капли. Вода на просвет почти не видна, а по краю отражает комнату:
// прозрачность растёт к краю по Френелю. Рябь бежит вдоль струи вместе с
// водой — v развёртки считает возраст воды в полёте — и дрожит по кругу.
// Цвет — из `custom.xyz`.
[[visible]]
void sproutWater(realitykit::surface_parameters params)
{
    float time = params.uniforms().time();
    float2 uv = params.geometry().uv0();
    float3 view = normalize(params.geometry().view_direction());
    float3 normal = normalize(params.geometry().normal());
    float facing = abs(dot(view, normal));
    float rim = pow(1.0 - facing, 3.0);

    float along = uv.y * 46.0 - time * 5.0;
    float around = uv.x * 6.2831853;
    float ripple = sin(along + sin(around * 2.0 + along * 0.37) * 1.4);
    float shiver = sin(around * 3.0 + along * 0.5);
    params.surface().set_normal(normalize(float3(0.22 * shiver,
                                                 0.3 * ripple,
                                                 1.0)));

    half3 tint = half3(params.uniforms().custom_parameter().xyz);
    float glint = smoothstep(0.55, 1.0, ripple) * 0.3;
    params.surface().set_base_color(tint);
    params.surface().set_roughness(0.025h);
    params.surface().set_metallic(0.0h);
    params.surface().set_specular(1.0h);
    params.surface().set_clearcoat(1.0h);
    params.surface().set_clearcoat_roughness(0.015h);
    params.surface().set_opacity(half(clamp(0.18 + 0.7 * rim + glint,
                                            0.0, 0.93)));
    params.surface().set_emissive_color(tint * half(0.03 + 0.12 * glint));
}

// Вода на земле горшка: от места, куда бьёт струя (`custom.xy` в
// развёртке диска), расходятся круги; `custom.w` — сколько воды, от нуля
// до единицы.
[[visible]]
void sproutPuddle(realitykit::surface_parameters params)
{
    float time = params.uniforms().time();
    float4 custom = params.uniforms().custom_parameter();
    float2 uv = params.geometry().uv0();
    float2 away = uv - custom.xy;
    float reach = length(away);
    float wave = sin(reach * 95.0 - time * 16.0);
    float closeness = exp(-reach * 5.0);
    float2 way = reach > 1.0e-4 ? away / reach : float2(0.0);
    params.surface().set_normal(normalize(float3(way * wave * 0.45 * closeness,
                                                 1.0)));
    params.surface().set_base_color(half3(0.36h, 0.4h, 0.44h));
    params.surface().set_roughness(0.02h);
    params.surface().set_metallic(0.0h);
    params.surface().set_specular(1.0h);
    float strength = clamp(custom.w, 0.0, 1.0);
    params.surface().set_opacity(half(strength
        * (0.28 + 0.4 * closeness * (0.5 + 0.5 * wave))));
}
