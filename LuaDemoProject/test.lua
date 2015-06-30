
waxClass{"TestView", UIView, protocols = {"UITextViewDelegate", "UIScrollViewDelegate"}}

function init(self)
    self.super:init()
    print("self.super:init")

       local singleRecognizer = UITapGestureRecognizer:initWithTarget_action(self, "SingleTap:");
       singleRecognizer:setNumberOfTapsRequired(1);
       --self:addGestureRecognizer(singleRecognizer);

  return self
end

function SingleTap(self, gesture)
    print("tap")
end

function hitTest_withEvent(self, point, event)
    self:removeFromSuperview()
end


function initWithFrame(self, frame)
    self.super:initWithFrame(frame)

    local label = UILabel:initWithFrame(CGRect(0, 0, 200, 50))
    label:setTextColor(UIColor:blackColor())
    label:setText("This Wax 64.")
    label:setCenter(CGPoint(frame.width/2, frame.height/2))
    label:setFont(UIFont:boldSystemFontOfSize(31))
    label:setTextAlignment(1)
    self:addSubview(label)
    return self
end



