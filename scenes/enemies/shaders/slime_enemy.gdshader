shader_type canvas_item;

void fragment() {
    // Get the distance from the current pixel to the center
    vec2 center = vec2(0.5, 0.5);
    float dist = distance(UV, center);
    
    // Create a circle shape with soft edges
    float circle = smoothstep(0.5, 0.4, dist);
    
    // Apply the circle as the alpha channel
    COLOR.a = circle * COLOR.a;
}