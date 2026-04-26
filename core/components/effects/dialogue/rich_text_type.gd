@tool
extends RichTextEffect
class_name RichTextType

# 这个字符串决定了在 BBCode 中使用什么标签，比如这里是 [type]
var bbcode = "type"

# 这个类用来让 RichTextLabel 支持单个字符的逐字显现
# 它的原理是：获取自文本开始渲染以来的总时间，
# 减去该标签设置的 delay（停顿），
# 然后乘以 speed（速度），计算出当前“应该”显示到第几个字符。
# 如果当前字符的索引大于这个计算值，它的透明度就是 0（不可见）。

func _process_custom_fx(char_fx: CharFXTransform) -> bool:
	# 1. 获取用户在标签中设置的参数，并给出默认值
	var speed: float = char_fx.env.get("speed", 25.0) # 默认每秒显示 25 个字符
	var delay: float = char_fx.env.get("delay", 0.0)  # 默认无停顿
	
	# 这个时间是从 RichTextLabel 的可见性或文本改变时开始计算的运行时间
	var time: float = char_fx.elapsed_time
	
	# 2. 计算这个字符什么时候“该”出现
	# 注意：char_fx.relative_index 是这个字符在这个 [type] 标签包裹块中的相对位置
	var time_to_appear = delay + (char_fx.relative_index / speed)
	
	# 3. 如果当前时间还没到它该出现的时间，就隐藏它（不占位）
	if time < time_to_appear:
		char_fx.visible = false
	else:
		char_fx.visible = true
	
	# 返回 true 表示我们成功处理了这个字符的变换
	return true
