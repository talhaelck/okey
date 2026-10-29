shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;
uniform sampler2D grain_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_texture : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 wood_color : source_color = vec4(.43,.32,.22,1.0);
uniform vec3 grain_scale = vec3(.65,.65,.65);
uniform float surface_roughness = .70;
varying vec3 local_pos;
varying vec3 local_normal;
void vertex() { local_pos=VERTEX; local_normal=NORMAL; }
void fragment() {
    vec3 p=local_pos*grain_scale;
    vec3 weights=pow(abs(local_normal),vec3(5.0));
    weights/=max(dot(weights,vec3(1.0)),.001);
    vec3 scan=texture(grain_texture,p.zy).rgb*weights.x
        +texture(grain_texture,p.xz).rgb*weights.y
        +texture(grain_texture,p.xy).rgb*weights.z;
    float lum=dot(scan,vec3(.2126,.7152,.0722));
    // Restrained scanned grain: no burned black streaks or orange patches.
    float detail=clamp((lum-.09)*4.8,-.28,.30);
    ALBEDO=wood_color.rgb*(1.0+detail);
    float wear=texture(rough_texture,p.xz).r*weights.y
        +texture(rough_texture,p.xy).r*weights.z+texture(rough_texture,p.zy).r*weights.x;
    ROUGHNESS=clamp(surface_roughness+(wear-.65)*.18,.48,.90);
    SPECULAR=.25;
    vec3 dx=dFdx(VERTEX), dy=dFdy(VERTEX);
    vec3 r1=cross(dy,NORMAL), r2=cross(NORMAL,dx);
    float det=dot(dx,r1);
    vec3 gradient=(dFdx(lum)*r1+dFdy(lum)*r2)*sign(det)/max(abs(det),.00001);
    NORMAL=normalize(NORMAL-gradient*.00018);
}
