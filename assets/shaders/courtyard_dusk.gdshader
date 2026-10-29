shader_type spatial;
render_mode unshaded;
varying float height;
void vertex(){height=(MODEL_MATRIX*vec4(VERTEX,1.0)).y;}
void fragment(){
    vec3 horizon=vec3(.17,.22,.25);
    vec3 dusk=vec3(.035,.065,.11);
    ALBEDO=mix(horizon,dusk,smoothstep(1.8,10.0,height));
}
