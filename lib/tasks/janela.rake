namespace :janela do
  desc "Report what this application still needs to do to use Janela correctly"
  task doctor: :environment do
    Janela::Doctor.new(Rails.root).report($stdout) or exit 1
  end
end
