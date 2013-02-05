class ConversationsController < ApplicationController
  before_filter :authenticate_user!

  respond_to :html, :mobile, :json, :js

  def index
    @conversations = Conversation.joins(:conversation_visibilities).where(
      :conversation_visibilities => {:person_id => current_user.person_id}).paginate(
      :page => params[:page], :per_page => 15, :order => 'updated_at DESC')

    @visibilities = ConversationVisibility.where(:person_id => current_user.person_id).paginate(
      :page => params[:page], :per_page => 15, :order => 'updated_at DESC')

    @unread_counts = {}
    @first_unread_message = Array.new
    @visibilities.each do |v| 
      @unread_counts[v.conversation_id] = v.unread
      @conversation = Conversation.find(v.conversation_id)
      #puts @conversation.messages.methods
      @message = @conversation.messages.all.at(@conversation.messages.count - v.unread)
      #puts @message.id
      if @message
        #puts "#{@message.id} #{@message.text}"
        @first_unread_message << @message.id
      end
    end

    @authors = {}
    @conversations.each { |c| @authors[c.id] = c.last_author }

    @conversation = Conversation.joins(:conversation_visibilities).where(
      :conversation_visibilities => {:person_id => current_user.person_id, :conversation_id => params[:conversation_id]}).first

    respond_with do |format|
      format.html
      format.json { render :json => @conversations, :status => 200 }
    end
  end

  def create
    person_ids = Contact.where(:id => params[:contact_ids].split(',')).map! do |contact|
      contact.person_id
    end

    params[:conversation][:participant_ids] = person_ids | [current_user.person_id]
    params[:conversation][:author] = current_user.person
    message_text = params[:conversation].delete(:text)
    params[:conversation][:messages_attributes] = [ {:author => current_user.person, :text => message_text }]

    @conversation = Conversation.new(params[:conversation])
    if person_ids.present? && @conversation.save
      Postzord::Dispatcher.build(current_user, @conversation).post
      flash[:notice] = I18n.t('conversations.create.sent')
    else
      flash[:error] = I18n.t('conversations.create.fail')
      if person_ids.blank?
        flash[:error] = I18n.t('conversations.create.no_contact')
      end
    end
    if params[:profile]
      redirect_to person_path(params[:profile])
    else
      redirect_to conversations_path(:conversation_id => @conversation.id)
    end
  end

  def show
    if @conversation = Conversation.joins(:conversation_visibilities).where(:id => params[:id],
                                                                            :conversation_visibilities => {:person_id => current_user.person_id}).first
                           
                           
      @first_unread_message = nil                                                 
      if @visibility = ConversationVisibility.where(:conversation_id => params[:id], :person_id => current_user.person.id).first
        @conversation = Conversation.find(@visibility.conversation_id)
        @message = @conversation.messages.all.at(@conversation.messages.count - @visibility.unread)
        if @message
          @first_unread_message = @message.id
        end  
        @visibility.unread = 0
        @visibility.save
      end

      respond_to do |format|
        format.html { redirect_to conversations_path(:conversation_id => @conversation.id, :anchor => "scroll_unread") }
        format.js
        format.json { render :json => @conversation, :status => 200 }
      end
    else
      redirect_to conversations_path
    end
  end

  def new
    all_contacts_and_ids = Contact.connection.select_rows(
      current_user.contacts.where(:sharing => true).joins(:person => :profile).
        select("contacts.id, profiles.first_name, profiles.last_name, people.diaspora_handle").to_sql
    ).map{|r| {:value => r[0], :name => Person.name_from_attrs(r[1], r[2], r[3]).gsub(/(")/, "'")} }

    @contact_ids = ""

    @contacts_json = all_contacts_and_ids.to_json
    if params[:contact_id]
      @contact_ids = current_user.contacts.find(params[:contact_id]).id
    elsif params[:aspect_id]
      @contact_ids = current_user.aspects.find(params[:aspect_id]).contacts.map{|c| c.id}.join(',')
    end
    if session[:mobile_view] == true && request.format.html?
    render :layout => true
    elsif
    render :layout => false
    end
  end
end
