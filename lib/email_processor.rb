class EmailProcessor

  require 'Staccato'

  def initialize(email)
    @email = email
    puts @email

    puts "Tracking GA: #{Settings.google_analytics_id}"
    @tracker = Staccato.tracker(Settings.google_analytics_id)

  end

  def process
    # scan users DB for sender email
    puts "Searching for user:#{@email.from[:email]}"

    @user = User.where(email: @email.from[:email]).first
    if @user.nil?
      puts "User not found, attempting to create"
      create_user
    else
      puts "User Found: #{@user.id}: #{@user.name}"
    end

    sitename = Settings.site_name

    # parse the email and find or create topic
#    if @email.body.multipart?
#      message = @email.text_part.body.decoded
#    else
#      message = @email.body.decoded
#    end

    message = @email.body

    #mail.multipart? ? message = mail.parts[-1].body.reverse.split('nO')[-1].reverse : message = mail.body.reverse.split('nO')[-1].reverse
    subject = @email.subject

    if subject.include?("[#{sitename}]") # this is a reply to an existing topic

      puts "Initiating Reply..."

      #Clean message
#      message = @email.raw_text
#      puts message

      complete_subject = subject.split("[#{sitename}]")[1].strip
      ticket_number = complete_subject.split("-")[0].split('#')[1].strip

      puts "Ticket Number: #{ticket_number}"

      topic = Topic.find(ticket_number)
      if topic
        puts "Subject match, adding to topic: " + subject.split("[#{sitename}]")[1].strip
      else
        puts "topic not found"
      end

      #insert post to new topic
      post = topic.posts.create(:body => message, :user_id => @user.id, :kind => 'reply')

      puts "Post #{post.id} Created"

      @tracker.event(category: 'Email', action: 'Inbound', label: 'Reply', non_interactive: true)
      @tracker.event(category: "Agent: #{topic.assigned_user.name}", action: 'User Replied by Email', label: topic.to_param)


    elsif subject.include?("Fwd: ") # this is a forwarded message

      puts "Forwarded message..."

      #clean message
      message = MailExtract.new(message).body

      #parse_forwarded_message(message)
      topic = Forum.first.topics.create(:name => @subject, :user_id => @parsed_user.id, :private => true)

      #insert post to new topic
      post = topic.posts.create(:body => @message, :user_id => @parsed_user.id)



    else # this is a new direct message

      puts "No subject match, creating new topic: " + subject
      topic = Forum.first.topics.create(:name => subject, :user_id => @user.id, :private => true)

      #insert post to new topic
      post = topic.posts.create(:body => message, :user_id => @user.id, :kind => 'first')

      # Call to GA
      @tracker.event(category: 'Email', action: 'Inbound', label: 'New Topic', non_interactive: true)
      @tracker.event(category: 'Agent: Unassigned', action: 'New', label: topic.to_param)

    end
  end

  def create_user
    # generate user password
    source_characters = "0124356789abcdefghijk"
    password = ""
    1.upto(8) { password += source_characters[rand(source_characters.length),1] }

    # create user
    puts "creating new user #{@email.from[:email]} #{@email.from[:name]}"
    @user = User.new
    @user.email = @email.from[:email]
    @user.name = @email.from[:name].blank? ? @email.from[:token] : @email.from[:name]
    @user.password = password
    if @user.save
      puts "user created, now sending mail"
      UserMailer.new_user(@user).deliver #if Settings.send_email == true
    else
      puts "user could not be saved"
    end

  end


end