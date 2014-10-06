BasicLayoutDrawLineMethods = 
  _draw_line: (parent, child, ctx)->
    # 在父子节点之间绘制连线
    return @_draw_line_0 parent, child, ctx if parent.is_root()
    @_draw_line_n parent, child, ctx

  # 在根节点上绘制曲线
  _draw_line_0: (parent, child, ctx)->
    # 绘制贝塞尔曲线
    # 两个端点
    # 父节点的中心点
    x0 = parent.layout_x_center
    y0 = parent.layout_y_center

    # 子节点的内侧中点
    x1 = child.layout_x_inside
    y1 = child.layout_y_center

    # 两个贝塞尔曲线控制点
    xc1 = x0 - 30 if child.side is 'left'
    xc1 = x0 + 30 if child.side is 'right'
    
    yc1 = y0

    xc2 = (x0 + x1) / 2.0
    yc2 = y1 

    ctx.lineWidth = 2
    ctx.strokeStyle = '#777'

    ctx.beginPath()
    ctx.moveTo x0, y0
    ctx.bezierCurveTo xc1, yc1, xc2, yc2, x1, y1 
    ctx.stroke()

  _draw_line_n: (parent, child, ctx)->
    # 绘制贝塞尔曲线
    # 两个端点
    # 父节点的折叠柄外侧中点
    x0 = parent.layout_x_joint_outside
    y0 = parent.layout_y_center

    # 子节点的内侧中点
    x1 = child.layout_x_inside
    y1 = child.layout_y_center

    # 两个贝塞尔曲线控制点
    xc1 = (x0 + x1) / 2.0
    yc1 = y0

    xc2 = xc1
    yc2 = y1

    ctx.lineWidth = 2
    ctx.strokeStyle = '#777'

    ctx.beginPath()
    ctx.moveTo x0, y0
    ctx.bezierCurveTo xc1, yc1, xc2, yc2, x1, y1 
    ctx.stroke()



class BasicLayout extends Module
  @include BasicLayoutDrawLineMethods

  constructor: (@mindmap)->
    @TOPIC_Y_PADDING = 10
    @TOPIC_X_PADDING = 30
    @JOINT_WIDTH = 16 # 折叠点的宽度


  go: ->
    root_topic = @mindmap.root_topic

    # 第一次遍历：深度优先遍历
    # 渲染(render)所有节点并且计算各个节点的布局数据
    @traverse_render root_topic

    # 根节点定位
    # 根节点的中心位置是 0, 0
    @pos root_topic, root_topic.layout_width / -2.0, root_topic.layout_height / -2.0

    # 第二次遍历：宽度优先遍历
    # 定位所有节点
    @traverse_pos root_topic


  traverse_render: (topic)->
    # 如果不是一级子节点/根节点，根据父节点的 side 来为当前节点的 side 赋值
    topic.side = topic.parent.side if topic.depth > 1
    topic.render()

    if topic.is_root()
      @_calc_layout_area topic, 'left_'
      @_calc_layout_area topic, 'right_'
    else
      @_calc_layout_area topic, ''


  _calc_layout_area: (topic, prefix)->
    # la = layout area
    # la 包含以下属性
    # la.height 当前区域高度（取节点高度和子节点高度中较大者）
    # la.children_height 所有子节点区域高度
    # la.children

    la = { children_height: -@TOPIC_Y_PADDING }
    if topic.is_opened()
      topic["#{prefix}children_each"] (i, child)=>
        @traverse_render child
        la.children_height += child.la.height + @TOPIC_Y_PADDING
    la.height = Math.max topic.layout_height, la.children_height
    topic["#{prefix}la"] = la


  traverse_pos: (topic)->
    if topic.is_root()
      @_calc_pos topic, 'left_'
      @_calc_pos topic, 'right_'
    else
      @_calc_pos topic, ''


  _calc_pos: (topic, prefix)->
    la = topic["#{prefix}la"]

    la.children_top = topic.layout_y_center - la.children_height / 2.0
    t = la.children_top
    topic["#{prefix}children_each"] (i, child)=>

      if child.side is 'left'
        left = topic.layout_left - @TOPIC_X_PADDING - child.layout_width
      if child.side is 'right'
        left = topic.layout_right + @TOPIC_X_PADDING

      top  = t + (child.la.height - child.layout_height) / 2.0
      @pos child, left, top
      @traverse_pos child
      t += child.la.height + @TOPIC_Y_PADDING


  draw_lines: ->
    # console.log '开始画线'
    root_topic = @mindmap.root_topic
    @_d_r root_topic

  _d_r: (topic)->
    if topic.has_children()
      # 如果当前节点有子节点，则创建针对该子节点的 canvas 图层
      ctx = @_init_canvas_on topic
      for child in topic.children
        # 每个子节点画一条曲线
        @_draw_line topic, child, ctx
        @_d_r child

  _init_canvas_on: (topic)->
    # 根节点
    if topic.is_root()
      left  = topic.layout_left_children_right - 50 # 左侧子节点的右边缘，向左偏移 50px
      right = topic.layout_right_children_left + 50 # 右侧子节点的左边缘，向右偏移 50px

      top = Math.min topic.layout_left_children_top, topic.layout_right_children_top # 所有子节点的上边缘
      bottom_left  = topic.layout_left_children_top + topic.layout_left_children_height # 左侧总高度
      bottom_right = topic.layout_right_children_top + topic.layout_right_children_height # 右侧总高度
      bottom = Math.max bottom_left, bottom_right

    else
      # 左侧节点
      if topic.side is 'left'
        left  = topic.layout_left_children_right - 50 # 所有子节点的右边缘，向左偏移 50px
        right = topic.layout_right # 当前节点的右边缘

      # 右侧节点
      if topic.side is 'right'
        left  = topic.layout_left # 当前节点的左边缘
        right = topic.layout_right_children_left + 50 # 所有子节点的左边缘，向右偏移 50px

      top    = topic.layout_left_children_top # 所有子节点的上边缘
      bottom = top + topic.layout_left_children_height # 所有子节点的下边缘

    # 计算 canvas 区域宽高
    width  = right - left
    height = bottom - top

    if not topic.$canvas
      topic.$canvas = jQuery '<canvas>'

    topic.$canvas
      .css
        'left': left
        'top': top
        'width': width
        'height': height
      .attr
        'width': width
        'height': height
      .appendTo @mindmap.$topics_area    

    ctx = topic.$canvas[0].getContext '2d'
    ctx.clearRect 0, 0, width, height
    ctx.translate -left, -top

    return ctx


  # 将节点定位到编辑器的指定相对位置
  # 同时计算一些布局方法会用到的值
  pos: (topic, left, top)->
    topic.layout_left = left
    topic.layout_top  = top
    
    topic.layout_right  = left + topic.layout_width
    topic.layout_bottom = top  + topic.layout_height

    topic.layout_x_center = left + topic.layout_width / 2.0
    topic.layout_y_center = top  + topic.layout_height / 2.0

    if topic.side is 'left'
      topic.layout_x_inside = topic.layout_right
      topic.layout_x_joint_outside = topic.layout_left - @JOINT_WIDTH

    if topic.side is 'right'
      topic.layout_x_inside = topic.layout_left
      topic.layout_x_joint_outside = topic.layout_right + @JOINT_WIDTH

    topic.$el.css
      left: topic.layout_left
      top: topic.layout_top

window.BasicLayout = BasicLayout