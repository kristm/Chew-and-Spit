#!/usr/local/bin/ruby
require 'singleton'
require 'rubygems'
require 'rghost'
require 'graphviz'

module PHPParser
    def self.class_def
        return /^class\s([a-zA-Z\_]+)(?:\sextends\s([a-zA-Z\_]+))?/
    end

    def self.property
        return /(public|protected|private)\s(\$[a-zA-Z\_\-]+)\;$/
    end

    def self.method
        return /(public|protected|private)?\s?function\s([a-zA-Z\_]+)\s?\(([a-zA-Z0-9\$\,\=\-\_\s]+)?\)\{?$/
    end

end

class MethodDef
    attr_accessor :name,:access,:params
    def initialize
        @params = []
    end
end

class Code
    include PHPParser
    attr_reader :dir, :props, :methods
    attr_accessor :class_name, :super_class

    def initialize(level,dir)
        @level = level.to_s
        @dir = dir
        @fn = ""
        @props = []
        @methods = []
    end

    def name=(name)
        @fn = name
    end

    def name
        return @fn
    end

    def process
        file = self.dir+"/"+self.name
        #add a case statement for parsing properties, methods, etc
        f = File.open(self.dir+"/"+self.name)
        begin
            f.each do |line|
                next if line =~ /^$/
                case line
                when PHPParser.class_def 
                    self.class_name = $1
                    self.super_class = $2 if $2 != nil
                when PHPParser.property
                    self.props << $2 if $2 != nil
                when PHPParser.method
                    method = MethodDef.new
                    method.name = $2
                    method.access = $1 if $1 != nil
                    method.params << $3 if $3 != nil
                    self.methods << method
                    #self.methods << $2 if $2 != nil
                end
            end
        ensure
            f.close unless f.nil?
        end
    end
end

class Repo
    include Singleton
    @@collection = []
    def Repo.collection= (obj)
        @@collection << obj
        #puts @@collection.length
    end

    def Repo.collection
        return @@collection
    end

    def Repo.class_exists? class_name
        return false if class_name.nil? or class_name[/^Zend/]
        @@collection.each do |obj|
            return true if obj.class_name == class_name
        end
        return false
    end
end

class Chew
    include Singleton
    def self.walk(dir='.',i=1)
        tab = "=="
        ind = " "
        Dir.foreach(dir) do |x|
            path = (i==1) ? x : dir+"/"+x
            next if dir =~ /library\/Zend/ or dir =~ /library\/TCPDF/ or dir =~ /library\/WCG/ or dir =~ /public/ or dir =~ /tests/
            if File.directory? path and x != '.' and x != '..' and x[0,1] != '.'
                a = ""
                i.times{a += tab}
                walk(path,i+1)
            else
                b = ""
                i.times{ b += ind}
                if x[/\.php$/] && x !~ /Bootstrap/
                    c = Code.new(i,dir)
                    c.name = x
                    Repo.collection = c
                    c.process 
                end
            end
        end
        return if i == 1
    end
    def self.spit
        #sort Repo.collection before doing anything
        for i in 0..Repo.collection.length-1
            j=0
            tmp = Repo.collection[i]
            i.downto(0) do |j|
                break if Repo.collection[j-1].dir < tmp.dir 
                Repo.collection[j] = Repo.collection[j-1] 
            end if i>0 
            Repo.collection[j] = tmp
        end

        doc = RGhost::Document.new
        gv = GraphViz::new("G")
        gv[:size] = "4,4"
        gv_set = {}
        doc.define_tags do
            tag :h1, :name=>'Helvetica-Bold', :size=>14, :color=>:blue
            tag :h2, :name=>'Helvetica', :size=>14, :color=>:red
            tag :h3, :name=>'Helvetica', :size=>12, :color=>:blue
            tag :h4, :name=>'Helvetica', :size=>12, :color=>:black
            tag :h5, :name=>'Helvetica', :size=>12, :color=>:red
            tag :h6, :name=>'Helvetica', :size=>10, :color=>:red
            tag :h7, :name=>'Helvetica', :size=>10, :color=>:blue
        end
        Repo.collection.each do |obj|
            gv_set[obj.class_name] = gv.add_node(obj.class_name) if not obj.class_name.nil?
            doc.next_row
            doc.show_next_row obj.dir, :with => :h4
            doc.next_row
            doc.show "class: #{obj.class_name}", :with => :h1
            doc.show_next_row "super class: #{obj.super_class}", :with => :h2 if obj.super_class != nil
            doc.show_next_row "Properties: ", :with => :h4
            doc.show_next_row "#{obj.props.join(',')}", :with => :h7 if obj.props.length > 0
            doc.show_next_row "Methods: ", :with => :h4
            obj.methods.each do |m|
                if m.access =~ /(protected|private)/ then
                    doc.next_row
                    doc.show "(#{m.access}) ", :with => :h5
                    doc.show "#{m.name}", :with => :h3
                else doc.show_next_row "#{m.name}", :with => :h3
                end
                doc.show " -- #{m.params.join}", :with => :h5 if m.params.length > 0
            end if obj.methods.length > 0
        end
        doc.render :pdf, :filename=>'rs_codes.pdf'
=begin
        gv_set.each do |node,value|
            n1 = value
            #need to add find class method in Repo. to retrieve parent class by class_name 
            #or just iterate Repo.collection again to build gv relationship if parent class found
            #in Repo.collection
        end
=end
        Repo.collection.shuffle.each do |obj|
            if Repo.class_exists? obj.super_class and not obj.super_class.nil?
                gv.add_edge(gv_set[obj.class_name],gv_set[obj.super_class]) 
            end
        end
        #gv.output( :pdf => "graph.pdf")
        #gv.output( :png => "graph.png")
        #gv.add_edge(gv_set['Application_Model_Categories'],gv_set['RiskSense_Model_Base'])
        #gv.add_edge(@appcat,@modelbase)
        #gv.output( :png => "graph.png")
        gv.output( :pdf => "graph.pdf")
    end
end

Chew.walk
Chew.spit
