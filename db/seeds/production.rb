ENV['RAILS_ENV'] = ARGV.first || ENV['RAILS_ENV'] || 'development'
require File.expand_path(File.dirname(__FILE__) + "/../../config/environment")

def create_registration_code(code)
  regcode = RegistrationCode.add_code code
  regcode.save!
  regcode
end
RegistrationCode.delete_all
if RegistrationCode.count == 0
  for i in 1..2 do
    create_registration_code "code#{i}"
  end
end

unless User.exist? 'TwitarrTeam'
  puts 'Creating user TwitarrTeam'
  user = User.new username: 'TwitarrTeam', display_name: 'TwitarrTeam', password: Rails.application.secrets.initial_admin_password,
    role: User::Role::ADMIN, status: User::ACTIVE_STATUS, email: 'admin@james.com', registration_code: 'code1'
  user.set_password Rails.application.secrets.initial_admin_password
  user.save
end

unless User.exist? 'official'
  puts 'Creating user official'
  user = User.new username: 'official', display_name: 'official', password: Rails.application.secrets.initial_official_password,
    role: User::Role::ADMIN, status: User::ACTIVE_STATUS, email: 'admin@james.com', registration_code: 'code2'
  user.set_password Rails.application.secrets.initial_official_password
  user.save
end

unless User.exist? 'official'
  raise Exception.new("No user named 'official'!  Create one first!")
end

def create_event(id, title, author, start_time, end_time, description, official)
  event = Event.create(_id: id, title: title, description: description, start_time: start_time, end_time: end_time, official: official)
  unless event.valid?
    puts "Errors for event #{title}: #{event.errors.full_messages}"
    return event
  end
  event.save!
  event
end

puts 'Creating events...'
cal_filename = "db/seeds/all.ics"
# fix bad encoding from sched.org
cal_text = File.read(cal_filename)
cal_text = cal_text.gsub(/&amp;/, '&').gsub(/(?<!\\);/, '\;')
if File.exists? cal_filename + ".tmp"
  File.delete(cal_filename + ".tmp")
end
File.open(cal_filename + ".tmp", "w") { |file| file << cal_text }

cal_file = File.open(cal_filename + ".tmp")
Icalendar::Calendar.parse(cal_file).first.events.map { |x| Event.create_from_ics x }

def create_reaction(tag)
  reaction = Reaction.add_reaction tag
  reaction.save!
  reaction
end

puts 'Creating reactions...'
Reaction.delete_all
if Reaction.count == 0
  create_reaction 'like'
  create_reaction 'love'
  create_reaction 'laugh'
end
