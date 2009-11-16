# Generated by jeweler
# DO NOT EDIT THIS FILE DIRECTLY
# Instead, edit Jeweler::Tasks in Rakefile, and run the gemspec command
# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{dm-adapter-simpledb}
  s.version = "1.0.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Jeremy Boles", "Edward Ocampo-Gooding", "Dan Mayer", "Thomas Olausson", "Avdi Grimm"]
  s.date = %q{2009-11-16}
  s.description = %q{A DataMapper adapter for Amazon's SimpleDB service. 

Features:
 * Uses the RightAWS gem for efficient SimpleDB operations.
 * Full set of CRUD operations
 * Supports all DataMapper query predicates.
 * Can translate many queries into efficient native SELECT operations.
 * Migrations
 * DataMapper identity map support for record caching
 * Lazy-loaded attributes
 * DataMapper Serial property support via UUIDs.
 * Array properties
 * Basic aggregation support (Model.count("..."))
 * String "chunking" permits attributes to exceed the 1024-byte limit

Note: as of version 1.0.0, this gem supports supports the DataMapper 0.10.*
series and breaks backwards compatibility with DataMapper 0.9.*.
}
  s.email = %q{devs@devver.net}
  s.extra_rdoc_files = [
    "README"
  ]
  s.files = [
    ".autotest",
     ".gitignore",
     "README",
     "Rakefile",
     "VERSION",
     "aws_config.sample",
     "dm-adapter-simpledb.gemspec",
     "lib/simpledb_adapter.rb",
     "lib/simpledb_adapter/sdb_array.rb",
     "scripts/simple_benchmark.rb",
     "spec/associations_spec.rb",
     "spec/compliance_spec.rb",
     "spec/date_spec.rb",
     "spec/limit_and_order_spec.rb",
     "spec/migrations_spec.rb",
     "spec/multiple_records_spec.rb",
     "spec/nils_spec.rb",
     "spec/sdb_array_spec.rb",
     "spec/simpledb_adapter_spec.rb",
     "spec/spec.opts",
     "spec/spec_helper.rb",
     "tasks/devver.rake"
  ]
  s.homepage = %q{http://github.com/devver/dm-adapter-simpledb}
  s.rdoc_options = ["--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.5}
  s.summary = %q{DataMapper adapter for Amazon SimpleDB}
  s.test_files = [
    "spec/nils_spec.rb",
     "spec/limit_and_order_spec.rb",
     "spec/compliance_spec.rb",
     "spec/simpledb_adapter_spec.rb",
     "spec/date_spec.rb",
     "spec/sdb_array_spec.rb",
     "spec/migrations_spec.rb",
     "spec/spec_helper.rb",
     "spec/multiple_records_spec.rb",
     "spec/associations_spec.rb"
  ]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<dm-core>, ["~> 0.10.0"])
      s.add_runtime_dependency(%q<dm-aggregates>, ["~> 0.10.0"])
      s.add_runtime_dependency(%q<uuidtools>, ["~> 2.0"])
      s.add_runtime_dependency(%q<right_aws>, ["~> 1.10"])
    else
      s.add_dependency(%q<dm-core>, ["~> 0.10.0"])
      s.add_dependency(%q<dm-aggregates>, ["~> 0.10.0"])
      s.add_dependency(%q<uuidtools>, ["~> 2.0"])
      s.add_dependency(%q<right_aws>, ["~> 1.10"])
    end
  else
    s.add_dependency(%q<dm-core>, ["~> 0.10.0"])
    s.add_dependency(%q<dm-aggregates>, ["~> 0.10.0"])
    s.add_dependency(%q<uuidtools>, ["~> 2.0"])
    s.add_dependency(%q<right_aws>, ["~> 1.10"])
  end
end

