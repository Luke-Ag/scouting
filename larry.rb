require 'sinatra/base'
require 'mongo'
require 'yaml'
require 'json'
require './lib/tba'

class ScoutingProject < Sinatra::Base
    configure do 
        client = Mongo::Client.new [ '127.0.0.1:27017' ], :database => 'unnamedScoutingProject' 
        db = client.database
        set :mongo_db, db[:unnamedScoutingProject]
        set :tba, TheBlueAlliance.new
    end
    before do
        @config = settings.mongo_db.find({ 'config' => 'CONFIG!' }).first
    end

    get '/larrage' do
        erb :im
    end
    get '/meme' do
        erb :mem
    end
    get '/adrian' do
        erb :zenith
    end
    get '/im' do
        erb :im
    end
    get '/' do
        erb :home
    end
    get '/chart' do
        erb :chart
    end
    get '/teams/:team' do
        @man = settings.mongo_db.find({team: params['team']}).to_a.to_json
    end
    get '/compare' do
        @matches = settings.mongo_db.find(team: {'$exists' => true}, match: {'$exists' => true}).map{|e| e}
        @teams = {}
        t = @matches.map{ |r| r[:team]}.uniq 
        @keys = @matches[0].keys.reject { |x| x == 'match' || x == 'team' || x.include?('Comment') || x == '_id' || x == 'Ability' || x == 'Defense'}
        t.each do |team|
            @teams[team] ||= {'team' => team.to_s.rjust(4, '0')}
            o = @matches.select{ |r| r[:team] == team }.count.to_f
            @keys.each do |k|
                @teams[team][k] = @matches.select{ |r| r[:team] == team }
                                          .map{ |r| r[k]}
                                          .reduce(0){ |sum, n| sum + (n.to_i || 0)} / o
            end
        end
        erb :compare
    end
    get '/trend' do
        @matches = settings.mongo_db.find(team: {'$exists' => true}, match: {'$exists' => true}).map{|e| e}
        @teams = {}
        t = @matches.map{ |r| r[:team]}.uniq 
        @keys = @matches[0].keys.reject { |x| x == 'match' || x == 'team' || x.include?('Comment') || x == '_id' || x == 'hatch-drop' || x == 'cargo-drop'}
        t.each do |team|
            @teams[team] ||= {'team' => team.to_s.rjust(4, '0')}
            o = @matches.select{ |r| r[:team] == team }.count.to_f
            @keys.each do |k|
                @teams[team][k] = @matches.select{ |r| r[:team] == team }
                                          .map{ |r| r[k]}
                                          .reduce(0){ |sum, n| sum + (n.to_i || 0)} / o
            end
        end
        erb :trending
    end
    get '/trend.json' do
        File.read('./stuff.json')
    end
    get '/import' do
        drive = `lsblk`.match(/─(sd\w\d)/)
        if drive
            drive = drive[1]
            `mkdir /export`
            `mount /dev/#{drive} /export`
            `cp /export/stuff.json ./stuff.json`
            `sync`
            `umount /export`

            "OK"
            erb :import
        else
            [401, "No USB Drive available: #{drive.inspect}"]
        end
    end
    get '/export' do
        drive = `lsblk`.match(/─(sd\w\d)/)
        if drive
            drive = drive[1]
            `mkdir /export`
            `mount /dev/#{drive} /export`
            data = settings.mongo_db.find(team: {'$exists' => true}, match: {'$exists' => true}).map{|e| e}.to_json
            File.open('/export/stuff.json', 'w+' ) do |f|
                f.write data
            end
            `sync`
            `umount /export`

            data
        else
            [401, "No USB Drive available: #{drive.inspect}"]
        end
    end
    get '/ynot' do
        erb :ynot
    end
    get '/red' do
        unless data = settings.mongo_db.find({futurematch: true}).first
            settings.mongo_db.insert_one({futurematch: true, R1: '', R2: '', R3: '', B1: '', B2: '', B3: '', MN: '', EV: ''})
            data = settings.mongo_db.find({futurematch: true}).first
        end
        @R1 = data['R1']
        @R2 = data['R2']
        @R3 = data['R3']
        @MN = data['MN']
        @EV = data['EV']
        @B1 = data['B1']
        @B2 = data['B2']
        @B3 = data['B3']
        @color = 'red'
        erb :index
    end
    get '/blue' do
        unless data = settings.mongo_db.find({futurematch: true}).first
            settings.mongo_db.insert_one({futurematch: true, R1: '', R2: '', R3: '', B1: '', B2: '', B3: '', MN: '', EV: ''})
            data = settings.mongo_db.find({futurematch: true}).first
        end
        @R1 = data['R1']
        @R2 = data['R2']
        @R3 = data['R3']
        @MN = data['MN']
        @EV = data['EV']
        @B1 = data['B1']
        @B2 = data['B2']
        @B3 = data['B3']
        @color = 'blue'
        erb :index
    end

    helpers do
        def partial(page, options={})
            erb page.to_sym, options.merge!(:layout => false)
        end
    end

    post "/form" do
        6.times do |i|
            obj = JSON.parse(params["payload#{i+1}"])
            if settings.mongo_db.find({match: obj[ 'match' ], team: obj[ 'team' ]}).first
                settings.mongo_db.find_one_and_update({match: obj[ 'match' ], team: obj[ 'team' ]}, {'$set' => obj})
            else
                settings.mongo_db.insert_one(obj)
            end
        end
        "OK"
    end

    get '/config' do
        erb :config
    end

    post "/config" do
        config = {}
        config['config'] = 'CONFIG!'
        config['title'] = params['title']
        puts config.to_yaml
        settings.mongo_db.update_one( {'config' => 'CONFIG!' }, config, upsert: true)
        'OK'
    end

    get '/all' do
        @data = settings.mongo_db.find(team: {'$exists' => true}, match: {'$exists' => true})
        erb :raw
    end

    get '/all.json' do
        settings.mongo_db.find.map{|e| e}.to_json
    end

    get '/raw' do
        hash = settings.mongo_db.find({team: {'$exists' => true}})
        hash.to_a.to_json
    end

    post '/raw/delete' do
        settings.mongo_db.delete_one({'_id' => BSON::ObjectId(params['id'])}).deleted_count.to_s
    end


    post '/raw/clear' do
        settings.mongo_db.delete_many({'team' => {'$exists' => true}, 'match' => {'$exists' => true}}).deleted_count.to_s
    end

    get '/raw/:team' do
        settings.mongo_db.find({team: params['team']}).to_a.to_json
    end

    get '/scoutmaster' do
        unless data = settings.mongo_db.find({futurematch: true}).first
            settings.mongo_db.insert_one({futurematch: true, R1: '', R2: '', R3: '', B1: '', B2: '', B3: '', MN: '', EV: ''})
            data = settings.mongo_db.find({futurematch: true}).first
        end
        @R1 = data['R1']
        @R2 = data['R2']
        @R3 = data['R3']
        @MN = data['MN']
        @EV = data['EV']
        @B1 = data['B1']
        @B2 = data['B2']
        @B3 = data['B3']
        erb :scoutmaster	
    end
    get '/future' do
        settings.mongo_db.find({futurematch: true}).first.to_json
    end

    post '/scoutmaster/submit' do
        data = {R1: params['R1'], R2: params['R2'], R3: params['R3'], B1: params['B1'], B2: params['B2'], B3: params['B3'], MN: params['MN'], EV: params['EV']}
        settings.mongo_db.find_one_and_update({futurematch: true}, {'$set' => data})
        redirect '/scoutmaster'
    end

    get '/events.json' do
        settings.mongo_db.find({event: {'$exists' => true}, matches: {'$exists' => true}}).to_a.to_json
    end

    get '/events/:key.json' do
        settings.mongo_db.find({event: params['key'], matches: {'$exists' => true}}).to_a[0].to_json
    end

    get '/scheduler' do
        @events = settings.tba.events
        erb :scheduler
    end

    get '/scheduler/:event' do
        @matches = settings.tba.getmatches params['event']
        @matches.to_json
    end

    post '/scheduler/:event' do
        @matches = settings.tba.getmatches params['event']
        settings.mongo_db.insert_one({'event' => params['event'], 'matches' => @matches})
        "OK"
    end
end
