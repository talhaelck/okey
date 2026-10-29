shader_type spatial;
render_mode unshaded;
uniform float power = 1.0;
void fragment() {
 vec2 p=UV;
 vec3 pitch=mix(vec3(.055,.12,.08),vec3(.09,.18,.11),step(.5,fract(p.x*9.0)));
 float border=step(.09,p.x)*step(p.x,.91)*step(.12,p.y)*step(p.y,.88);
 float center=1.0-smoothstep(.002,.006,abs(p.x-.5));
 float circle=1.0-smoothstep(.004,.009,abs(length((p-.5)*vec2(1.0,.7))-.13));
 pitch=mix(pitch,vec3(.32,.37,.28),max(center,circle)*.45);
 float scan=.96+.04*sin(p.y*480.0);
 ALBEDO=pitch*border*scan*power;
}
