/*
	格子草シェーダー by あるる（きのもと 結衣） @arlez80
	Grid Grass Shader by Yui Kinomoto @arlez80

	MIT License
*/
shader_type spatial;

// 草画像
uniform sampler2D albedo_tex : hint_albedo;
// 格子サイズ
uniform float grid = 0.54;
// 草の高さ
uniform float height = 1.0;
// 揺れ度合い
uniform vec3 frequency_rate = vec3( 0.03, 0.0, 0.06 );
// 揺れ速度
uniform float frequency_speed = 1.0;
// 重ねる回数
uniform int overlap_count = 12;

uniform float metallic = 0.2;
uniform float roughness = 0.2;

// モデル/ローカル座標
varying vec3 model_vertex;

void vertex( )
{
	model_vertex = VERTEX;
}

/**
 * 面チェック
 */
void check_surface( int i, float ray_dir, float surface_plane, inout float min_t, inout int id )
{
	float old_min_t = min_t;
	bool is_flip = ray_dir < 0.0;
	float t = - ( surface_plane + float( is_flip ) * grid ) / ray_dir;
	min_t = min( min_t, t );
	id = max( id, ( int( is_flip ) + i * 2 ) * int( min_t < old_min_t ) );
}

void fragment( )
{
	vec3 ray_dir = ( -( vec4( VIEW, 1.0 ) ) * INV_CAMERA_MATRIX ).xyz;
	vec3 surface = mod( model_vertex, -vec3( grid ) );

	// 格子チェック
	vec4 color = vec4( 0.0, 0.0, 0.0, 0.0 );
	float t = TIME * frequency_speed;
	for( int i=0; i<overlap_count; i++ ) {
		float min_t = 1e10;
		int id = -1;
		check_surface( 0, ray_dir.x, surface.x, min_t, id );
		check_surface( 2, ray_dir.z, surface.z, min_t, id );

		vec3 hit = model_vertex + min_t * ray_dir;
		hit.y = clamp( -hit.y, -height, 0.0 ) / height;

		hit.x += sin( t ) * frequency_rate.x * hit.y;// + float(i) * 0.7;
		hit.z += cos( t ) * frequency_rate.z * hit.y;// - float(i) * 0.7;

		// 色決定
		vec4 new_color = (
			// X+ X-
			textureLod( albedo_tex, vec2( hit.z, hit.y ), 0 ) * float( id == 0 || id == 1 )
			// Z+ Z-
		+	textureLod( albedo_tex, vec2( hit.x, hit.y ), 0 ) * float( id == 4 || id == 5 )
		);
		new_color.a *= float( -0.995 < hit.y && hit.y < 0.0 );
		NORMAL = mix(
			( INV_CAMERA_MATRIX * WORLD_MATRIX * 
			vec4(
				- float( id == 0 ) + float( id == 1 )
			,	0.0
			,	- float( id == 4 ) + float( id == 5 )
			,	0.0
			) ).xyz
		,	NORMAL
		,	color.a
		);
		color.rgb = mix( new_color.rgb, color.rgb, clamp( color.a + 1.0 - new_color.a, 0.0, 1.0 ) );
		color.a = max( color.a, new_color.a );
		surface.x -= sign( ray_dir.x ) * float( id == 0 || id == 1 ) * grid;
		surface.z -= sign( ray_dir.z ) * float( id == 4 || id == 5 ) * grid;
	}
	ALBEDO = color.rgb;
	ALPHA = color.a;
	METALLIC = metallic;
	ROUGHNESS = roughness;

	// ALBEDO = model_vertex.rgb;
	// ALPHA = 1.0;
	// ALBEDO = NORMAL;
}
