#!/usr/local/bin/ruby

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

    def self.ref_method
        return /new\s([a-zA-Z\_]+)/
    end
end
