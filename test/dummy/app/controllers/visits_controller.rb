# The demo reading its own traffic. The frame is rows (ADR 012), arranged
# through Janela::Tools like any other.
class VisitsController < ApplicationController
  def show
    @frame = policy_scope(Janela::Frame).find_by(name: PageView::FRAME)
  end
end
