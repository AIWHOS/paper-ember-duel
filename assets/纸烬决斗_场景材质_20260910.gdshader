shader_type spatial;
render_mode diffuse_burley;
uniform vec4 base_color : source_color = vec4(0.24,0.22,0.19,1.0);
uniform float grain_scale = 12.0;
uniform float grain_strength = 0.16;
uniform bool wood = false;
varying vec3 world_vertex;
float hash(vec3 p) { p=fract(p*0.3183099+vec3(0.1,0.2,0.3));p*=17.0;return fract(p.x*p.y*p.z*(p.x+p.y+p.z)); }
float noise(vec3 p) {vec3 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);}
void vertex(){world_vertex=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec3 p=world_vertex*grain_scale;
 if(wood){p*=vec3(0.08,1.0,2.0);}
 float coarse=noise(p*0.25);
 float fine=noise(p*6.0);
 float chip=smoothstep(0.69,0.76,noise(p*1.3));
 float shade=1.0-grain_strength*(0.7-coarse+0.8*fine+chip);
 ALBEDO=base_color.rgb*shade;
 ROUGHNESS=0.88+fine*0.1;
}
