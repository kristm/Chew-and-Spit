#!/usr/local/bin/ruby
require 'singleton'
require 'rubygems'
require 'rghost'
require 'graphviz'
require File.dirname(__FILE__) + '/parser/php_parser'


class MethodDef
    attr_accessor :name,:access,:params
    def initialize
        @params = []
    end
end

class Code
    include PHPParser
    attr_reader :dir, :props, :methods
    attr_accessor :class_name, :super_class, :ref_method

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
                when PHPParser.ref_method
                    self.ref_method = $1
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
    @@cluster = {}
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

    def Repo.get_dir class_name
        @@collection.each do |obj|
            return obj.dir if obj.class_name == class_name
        end
        return nil
    end

    def Repo.pack(key,value)
        @@cluster[key] = value
    end

    def Repo.cluster
        return @@cluster
    end
end

class Chew
    include Singleton

    @@exclude_dir = []

    def self.exclude_dir= (*patterns)
        patterns = patterns.flatten
        patterns.each do |pattern|
            @@exclude_dir << pattern
        end
    end

    def self.exclude_dir? val
        @@exclude_dir.each do |pattern|
            return true if val =~ pattern
        end
        return false
    end

    def self.walk(dir='.',i=1)
        tab = "=="
        ind = " "
        Dir.foreach(dir) do |x|
            path = (i==1) ? x : dir+"/"+x
            next if self.exclude_dir? dir
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
    def self.spit outfile
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
        gv.edge[:color] = "red"
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

        lastdir = nil
        ci = 0
        Repo.collection.each do |obj|
            if obj.dir != lastdir 
                lastdir = obj.dir
                cluster_name = "cluster#{ci}"
                Repo.pack(obj.dir,cluster_name)
                gv.send(cluster_name.to_sym,:label=>obj.dir) {|x| }
                ci += 1
            end
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
        doc.render :pdf, :filename=>"#{outfile}"

        lastdir = nil
        mod_re = /[a-zA-Z]+$/
        Repo.collection.each do |obj|
            if Repo.class_exists? obj.super_class and not obj.super_class.nil?
                gv.edge[:color] = "black"
                #find dir of class and super class so you can find its cluster
                super_dir = Repo.get_dir obj.super_class
                sub_dir = Repo.get_dir obj.class_name
                eval("gv."+Repo.cluster[super_dir]+"."+obj.super_class[mod_re]) << eval("gv."+Repo.cluster[sub_dir]+"."+obj.class_name[mod_re])
            end
            if Repo.class_exists? obj.ref_method and not obj.ref_method.nil?
                gv.edge[:color] = "red"
                ref_dir = Repo.get_dir obj.ref_method
                sub_dir = Repo.get_dir obj.class_name
                eval("gv."+Repo.cluster[sub_dir]+"."+obj.class_name[mod_re]) << eval("gv."+Repo.cluster[ref_dir]+"."+obj.ref_method[mod_re])
                
            end
        end

        gv.output( :pdf => "graph.pdf")
    end
end

def main
    if ARGV.length == 0
        puts "Usage: #{$0} outfile"
        exit
    end

    outfile = ARGV[0]

    Chew.exclude_dir = /library\/Zend/,/library\/TCPDF/,/library\/WCG/,/public/,/tests/
    Chew.walk
    Chew.spit outfile
end

main() if __FILE__ == $0
