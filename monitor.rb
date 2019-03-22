#!/usr/bin/env ruby
# coding: utf-8
#encoding: utf-8
require 'rubygems'
require 'sinatra/base'
require 'sprockets'
require 'uglifier'
require 'sass'
require 'yaml/store'
require 'sinatra/flash'
require 'sinatra/cookies'
require 'fileutils'
require 'securerandom'
require 'sinatra/form_helpers'
require 'sinatra/session'
require 'mail'
require 'erb'
require 'csv'
require 'builder'
require 'bcrypt'

class App < Sinatra::Base
    helpers Sinatra::Cookies
    helpers Sinatra::FormHelpers
    enable :sessions
    register Sinatra::Flash
    set :protection, :except => :frame_options
    set :cookie_options, :domain => nil
    register Sinatra::Session
    set :session_secret, ENV['PASSWORDHASH']
    use Rack::Session::Cookie, :key => 'rack.session',
                               :path => '/',
                               :expire_after => 2000, # In seconds
                               :secret => ENV['PASSWORDHASH']
    

    # initialize new sprockets environment
    set :environment, Sprockets::Environment.new

    # append assets paths
    environment.append_path "assets/css"
    environment.append_path "assets/js"

    # compress assets
    environment.js_compressor  = Uglifier.new(harmony: true)
    environment.css_compressor = :scss

    helpers do
        def createDB()
            if !(File.file?("devices.yml")) 
                store = YAML::Store.new 'devices.yml'
                store.transaction do
                    store['admin'] ||= {}
                    store['online'] ||= []
                    store['devices'] ||= {}
                end
                createAdmin()
            end
        end

        def createAdmin()
            store = YAML::Store.new 'devices.yml'
            username = ENV['MAIL1']
            password_plain = SecureRandom.hex
            setAdmin(username, password_plain)
        end

        def setAdmin(username, password_plain)
            store = YAML::Store.new 'devices.yml'
            password = BCrypt::Password.create(password_plain).to_s
            data = {}
            data["headline"] = "Ein neuer Admin wurde erstellt."
            data["boddy"] = {}
            data["boddy"]["username"] = username
            data["boddy"]["password"] = password_plain

            writeMail(["#{ENV['MAIL1']}"], data)
            store.transaction do
                store['admin']["username"] = username
                store['admin']["password"] = password
            end
        end

        def getAdmin()
            store = YAML::Store.new 'devices.yml'
            admin = store.transaction { store['admin'] }
        end

        def check_credentials(username, password)
            admin = getAdmin()
            if admin["username"] == username && BCrypt::Password.new(admin["password"]) == password
                return true
            end
            return false
        end

        def getDevicesFromDB()
            store = YAML::Store.new 'devices.yml'
            devices = store.transaction { store['devices'] }
        end

        def getDeviceFromDB(name)
            store = YAML::Store.new 'devices.yml'
            device = store.transaction { store['devices'][name] }
        end

        def createTimeHash(sessions, name)
            sessionCount = sessions.length
            if sessionCount == 0
                sessions[sessionCount] = {}
                sessions[sessionCount][0] = Time.now.to_s
                sessions[sessionCount][1] = Time.now.to_s
                setOnline(name)
                return sessions
            end
            oldTimestamp = sessions[sessionCount -1]
                                
            if Time.parse(oldTimestamp[1]) < Time.parse(Time.now.to_s) -15             
                sessions[sessionCount] = {}
                sessions[sessionCount][0] = Time.now.to_s
                sessions[sessionCount][1] = Time.now.to_s
                setOnline(name)                               
            else                                               
                sessions[sessionCount -1][1] = Time.now.to_s                         
            end
            sessions
        end

        def checkOnline(sessions)
            sessionCount = sessions.length
            oldTimestamp = sessions[sessionCount -1]
            if Time.parse(oldTimestamp[1]) < Time.parse(Time.now.to_s) -15             
                return false          
            else                                               
                return true
            end
        end

        def getOnlineFromDB()
            store = YAML::Store.new 'devices.yml'
            online = store.transaction { store['online'] }
            if online.length == 0
                return online
            end
            actualOnline = []
            online.each do |name|
                device = getDeviceFromDB(name)
                if checkOnline(device["sessions"])
                actualOnline.push(name)
                end
            end
            actualOnline
        end

        def setOnline(name)
            oldOnline = getOnlineFromDB()
            oldOnline.push(name)
            store = YAML::Store.new 'devices.yml'
            store.transaction do
                store['online'] = oldOnline.uniq
            end
        end

        def saveDevice(data)
            name = data["name"]
            oldDevices = getDevicesFromDB()
            device = {}
            device["sessions"] = {}
            sessions = device["sessions"]
            if oldDevices.keys.include?(name)
                device = oldDevices[name]
                sessions = oldDevices[name]["sessions"]
            end
            session = createTimeHash(sessions, name)
            session[session.keys.last]["uptime"] = data["uptime"]
            session[session.keys.last]["temp"] = data["temp"].to_f
            session[session.keys.last]["ip"] = data["ip"]
            session[session.keys.last]["load"] = data["load"].to_f
            session[session.keys.last]["max_load"] = data["max_load"].to_f
            device["sessions"] = session
            store = YAML::Store.new 'devices.yml'
            store.transaction do
                store['devices'][name] = device
            end
        end

        def compileBody(text)
            @text = text
            if @text["boddy"].is_a?(Hash)
                xm = Builder::XmlMarkup.new(:indent => 2)
                xm.table {
                    xm.tr { @text["boddy"].keys.each { |key| xm.th(key)}}
                    @text["boddy"].values.each { |value| xm.td(value)}
                }
                @boddy = xm
            else 
                @boddy = @text["boddy"]
            end    
            mail = ERB.new(File.read('./views/mail.erb').force_encoding("UTF-8")).result(binding)
        end

        def writeMail(recipients, params)
            compileBody(params)
            user = ENV['MAILUSER']
            pass = ENV['MAILPASSWORD']
            mail = ERB.new(File.read('./views/mail.erb').force_encoding("UTF-8")).result(binding)
            options = { 
            :address              => "mail.th-brandenburg.de",
            :port                 => 25,
            :user_name            => user,
            :password             => pass,
            :authentication       => 'plain',
            :enable_starttls_auto => true  }
            # Set mail defaults
            Mail.defaults do
            delivery_method :smtp, options
            end
            recipients.each do |m|
            Mail.deliver do
                to "#{m}"
                from "#{ENV['MAIL2']}"
                subject "AWW File Upload"
                content_type 'text/html; charset=UTF-8'
                body "#{mail}"
            end
            end
        end

        def get_all_load()
            allDevices = getDevicesFromDB()
            cpuLoad = []
            allDevices.each_key do |k|
                allDevices[k]["sessions"].each_key do |s|
                    cpuLoad.push(allDevices[k]["sessions"][s]["load"].to_f)
                end
            end
            cpuLoad
        end
        def get_all_temp()
            allDevices = getDevicesFromDB()
            temp = []
            allDevices.each_key do |k|
                allDevices[k]["sessions"].each_key do |s|
                    temp.push(allDevices[k]["sessions"][s]["temp"].to_f)
                end
            end
            temp
        end

    end

    not_found do
        @headline = "404"
        erb :general_response
      end
    
    error do
        @headline = "Bitte entschuldigen Sie,"
        @lead_text = "es ist ein Fehler aufgetreten. Bitte versuchen Sie es später noch einmal."
        erb :general_response
    end

    get "/assets/*" do
        env["PATH_INFO"].sub!("/assets", "")
        settings.environment.call(env)
    end

    get '/' do
        createDB()
        if session[:passwordhash] == ENV['PASSWORDHASH']
            redirect "backend"
        else
            erb :index
        end    
    end

    post '/backend' do
        if check_credentials(params["inputEmail"], params["inputPassword"])
          session[:passwordhash] = ENV['PASSWORDHASH']
        end
        redirect "backend"
    end
    
    get '/backend' do
        if session[:passwordhash] == ENV['PASSWORDHASH']
          store = YAML::Store.new 'devices.yml'
          devices = getDevicesFromDB()
          erb :backend
        else
          flash[:error] = "E-Mail-Adresse oder Password Falsch."
          redirect "/login"
        end
    end

    get '/sign_out' do
        session.clear
        redirect '/'
    end

    get '/report' do
        content_type 'application/json'
        if params["token"] == "bar"
            saveDevice(params)
            {:status => "success"}.to_json
        else
            {:status => "error"}.to_json
        end
    end

    get '/online' do
        content_type 'application/json'
        getOnlineFromDB().to_json
    end

    get '/sessions' do
        content_type 'application/json'
        getDevicesFromDB().to_json
    end

    get '/offline' do
        content_type 'application/json'
        online = getOnlineFromDB()
        all = getDevicesFromDB().keys
        online.each do |n|
            all.delete(n)
        end
        all.to_json
    end
    
    get '/allload' do
        content_type 'application/json'
        load = get_all_load()
        avg_load = load.reduce(:+).to_f / load.size
        {:load => avg_load}.to_json
    end

    get '/alltemp' do
        content_type 'application/json'
        temp = get_all_temp()
        avg_temp = temp.reduce(:+).to_f / temp.size
        {:temp => avg_temp}.to_json
    end

    get "/getdate" do
        content_type 'application/json'
        {:date => DateTime.now}.to_json
    end

end

