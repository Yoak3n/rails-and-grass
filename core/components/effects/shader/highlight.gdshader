shader_type canvas_item;

// 可以在面板里动态调节的参数
uniform vec4 line_color : source_color = vec4(1.0, 1.0, 1.0, 1.0); // 轮廓颜色，默认白色
uniform float line_thickness : hint_range(0, 10) = 1.0;            // 轮廓粗细

// 决定周围 8 个方向的采样点（经典的八向膨胀算法）
const vec2 OFFSETS[8] = {
	vec2(-1, -1), vec2(-1, 0), vec2(-1, 1), vec2(0, -1), vec2(0, 1), 
	vec2(1, -1), vec2(1, 0), vec2(1, 1)
};

void fragment() {
    // 1. 获取当前像素的纹理颜色和透明度
	vec4 color = texture(TEXTURE, UV);
	
    // 2. 如果当前像素已经是实心的（物品本体），直接显示本体，不做处理
	if (color.a > 0.0) {
		COLOR = color;
	} else {
        // 3. 如果当前像素是透明的（物品外部），去检测它周围有没有实心像素
		vec2 size = TEXTURE_PIXEL_SIZE * line_thickness;
		float outline = 0.0;
		
		for (int i = 0; i < 8; i++) {
			outline += texture(TEXTURE, UV + size * OFFSETS[i]).a;
		}
		
        // 4. 如果周围有实心像素（说明这个透明像素紧贴着物品边缘），就把它染成高光颜色
		if (outline > 0.0) {
			COLOR = line_color;
		} else {
			COLOR = color; // 否则保持透明
		}
	}
}