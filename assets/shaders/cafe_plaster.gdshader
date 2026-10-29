shader_type spatial;
render_mode diffuse_burley;
uniform sampler2D surface_scan : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 plaster_color : source_color = vec4(.68,.64,.55,1.0);
uniform vec4 exposed_plaster : source_color = vec4(.52,.49,.41,1.0);
varying vec3 world_pos;
varying vec3 object_normal;
void vertex() { world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; object_normal=NORMAL; }
void fragment() {
    vec3 w=pow(abs(object_normal),vec3(5.0));w/=max(dot(w,vec3(1.0)),.001);
    vec3 p=world_pos*.42;
    vec3 scan=texture(surface_scan,p.zy).rgb*w.x+texture(surface_scan,p.xz).rgb*w.y+texture(surface_scan,p.xy).rgb*w.z;
    float h=dot(scan,vec3(.2126,.7152,.0722));
    // Worn paint and exposed older plaster follow the existing scanned surface.
    float wear=1.0-smoothstep(.06,.12,h);
    float patch_area=smoothstep(.25,.75,sin(world_pos.x*1.37+world_pos.z*.82+world_pos.y*.51)*.5+.5);
    vec3 paint=plaster_color.rgb*(1.0+clamp((h-.25)*.20,-.035,.035));
    ALBEDO=mix(paint,exposed_plaster.rgb,wear*patch_area*.30);
    ROUGHNESS=.94;SPECULAR=.12;
    vec3 dx=dFdx(VERTEX),dy=dFdy(VERTEX);
    vec3 r1=cross(dy,NORMAL),r2=cross(NORMAL,dx);
    float det=dot(dx,r1);
    vec3 gradient=(dFdx(h)*r1+dFdy(h)*r2)*sign(det)/max(abs(det),.00001);
    NORMAL=normalize(NORMAL-gradient*.00065);
}
