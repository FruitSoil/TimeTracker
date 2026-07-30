shader_type canvas_item;

void fragment() {
    // Нормализуем координаты пикселей
    vec2 uv = UV;
    
    // Создаем медленное движение волн за счет времени
    float wave1 = sin(uv.x * 4.0 + TIME * 0.4) * 0.5 + 0.5;
    float wave2 = cos(uv.y * 3.0 - TIME * 0.3) * 0.5 + 0.5;
    
    // Смешиваем базовый темно-серый цвет с глубоким полупрозрачным синим
    vec3 base_color = vec3(0.12, 0.12, 0.14); // #1f1f24
    vec3 accent_color = vec3(0.15, 0.20, 0.32); // Спокойный сине-серый
    
    // Итоговый цвет плавно переливается
    vec3 final_color = mix(base_color, accent_color, (wave1 + wave2) * 0.4);
    
    COLOR = vec4(final_color, 1.0);
}
