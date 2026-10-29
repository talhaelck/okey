shader_type spatial;
render_mode diffuse_burley;
uniform vec4 ceramic_color : source_color = vec4(.66,.69,.62,1.0);
uniform vec4 motif_color : source_color = vec4(.47,.55,.48,1.0);
varying vec3 wall_pos;
void vertex(){ wall_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment(){
    vec2 uv=vec2(wall_pos.x+wall_pos.z,wall_pos.y)/.22;
    vec2 cell=fract(uv)-.5;
    float radius=length(cell);
    float angle=atan(cell.y,cell.x);
    float aa=max(fwidth(radius),.002);
    float outline=.24+.035*cos(angle*8.0);
    float rosette=1.0-smoothstep(.009,.009+aa,abs(radius-outline));
    float centre=1.0-smoothstep(.022,.022+aa,abs(radius-.07));
    float corner=1.0-smoothstep(.018,.018+aa,abs(abs(cell.x)+abs(cell.y)-.61));
    float motif=max(max(rosette,centre),corner*.55);
    float edge=min(.5-abs(cell.x),.5-abs(cell.y));
    float grout=1.0-smoothstep(.002,.009,edge);
    vec3 base=mix(ceramic_color.rgb,motif_color.rgb,motif*.55);
    base=mix(base,ceramic_color.rgb*.85,grout*.55);
    float border=1.0-smoothstep(.002,.005,abs(wall_pos.y-.853));
    ALBEDO=mix(base,motif_color.rgb,border*.50);
    ROUGHNESS=.74;SPECULAR=.22;
}
