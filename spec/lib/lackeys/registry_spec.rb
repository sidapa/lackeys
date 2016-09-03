# frozen_string_literal: true

require 'spec_helper'

describe Lackeys::Registry, type: :class do
  subject(:registry) { Lackeys::Registry }

  describe '::register' do
    subject(:method) { Lackeys::Registry.register(params) { |_x| } }
    let(:params) { Integer }

    context 'no block given' do
      subject(:method) { Lackeys::Registry.register(params) }
      let(:error_msg) { 'Registry#register requires a block' }

      it { expect { method }.to raise_error error_msg }
    end

    it { should be_nil }

    it 'yields an instance of Lackeys::Registration' do
      reg_double = double

      expect(Lackeys::Registration)
        .to receive(:new)
        .with(params)
        .and_return(reg_double)
      expect(reg_double).to receive(:register_method).with(:test)
      expect(Lackeys::Registry).to receive(:add).with(reg_double)

      registry.register(params) { |r| r.register_method :test }
    end
  end

  describe '::call' do
    let(:source) { double }
    let(:source2) { double }
    let(:obs) { [source, source2] }
    let(:contents) { { foo: { multi: false, observers: obs } } }
    let(:method_name) { :foo }
    let(:calling_obj) { double }
    subject(:method) do
      Lackeys::Registry.call method_name, calling_obj, 1, 2
    end

    before(:each) do
      @methods = Lackeys::Registry.instance_variable_get(:@registered_methods)
      Lackeys::Registry.instance_variable_set(:@registered_methods, contents)
    end

    after(:each) do
      Lackeys::Registry.instance_variable_set(:@registered_methods, @methods)
    end

    it 'should call method from source passing calling_obj and args' do
      expect(source).to receive(method_name).with(calling_obj, 1, 2)
      expect(source2).to receive(method_name).with(calling_obj, 1, 2)
      method
    end

    it 'should return an array or returned values' do
      allow(source)
        .to receive(method_name)
        .with(calling_obj, 1, 2)
        .and_return('foo')
      allow(source2)
        .to receive(method_name)
        .with(calling_obj, 1, 2)
        .and_return('bar')
      expect(method).to eql(%w(foo bar))
    end

    context 'only 1 source' do
      let(:contents) { { foo: { multi: false, observers: [source] } } }

      it 'should return an array or returned values' do
        allow(source)
          .to receive(method_name)
          .with(calling_obj, 1, 2)
          .and_return('foo')
        expect(method).to eql('foo')
      end
    end

    context 'method_name passed is a string' do
      let(:method_name) { 'foo' }

      it 'should call method from source passing calling_obj and args' do
        expect(source).to receive(method_name.to_sym).with(calling_obj, 1, 2)
        expect(source2).to receive(method_name.to_sym).with(calling_obj, 1, 2)
        method
      end
    end

    context 'method does not exist' do
      let(:method_name) { :bar }
      let(:error_msg) { 'bar has not been registered' }

      it { expect { method }.to raise_error error_msg }
    end
  end

  describe '::method?' do
    let(:param) { Lackeys::Registration.new(source) }
    let(:source) { Integer }
    let(:contents) { { foo: { multi: false, observers: [String] } } }
    let(:method_name) { :foo }
    subject(:method) { Lackeys::Registry.method? method_name }

    before(:each) do
      @methods = Lackeys::Registry.instance_variable_get(:@registered_methods)
      Lackeys::Registry.instance_variable_set(:@registered_methods, contents)
      param.add_method method_name
    end

    after(:each) do
      Lackeys::Registry.instance_variable_set(:@registered_methods, @methods)
    end

    it { should eql(true) }

    context 'method has not been registered' do
      let(:method_name) { :bar }

      it { should eql(false) }
    end

    context 'method name is a string' do
      let(:method_name) { 'foo' }

      it { should eql(true) }
    end
  end

  describe '::add' do
    subject(:method) { Lackeys::Registry.add(parameter) }
    let(:param) { Lackeys::Registration.new(source) }
    let(:source) { Integer }
    let(:option) { {} }

    context '@registered_methods' do
      let(:method_name) { :foo }
      let(:contents) { {} }
      let(:error_msg) { 'foo has already been registered' }
      before(:each) do
        @methods = Lackeys::Registry.instance_variable_get(:@registered_methods)
        Lackeys::Registry.instance_variable_set(:@registered_methods, contents)
        param.add_method method_name, option
      end

      after(:each) do
        Lackeys::Registry.instance_variable_set(:@registered_methods, @methods)
      end

      it 'adds the method' do
        methods = Lackeys::Registry.instance_variable_get(:@registered_methods)
        Lackeys::Registry.add(param)
        expect(methods[method_name])
          .to eql(multi: false, observers: [Integer])
      end

      context 'a multi: false method has already been registered' do
        let(:contents) { { foo: { multi: false, observers: [String] } } }

        it { expect { Lackeys::Registry.add(param) }.to raise_error error_msg }
      end

      context 'add a allow_multi: true method' do
        let(:option) { { allow_multi: true } }
        let(:add_method) { Lackeys::Registry.add(param) }

        it 'adds the method' do
          Lackeys::Registry.add(param)
          mthods = Lackeys::Registry.instance_variable_get(:@registered_methods)
          expect(mthods[method_name])
            .to eql(multi: true, observers: [Integer])
        end

        context 'a multi: false method has already been registered' do
          let(:contents) { { foo: { multi: false, observers: [String] } } }

          it { expect { add_method }.to raise_error error_msg }
        end
      end
    end

    context '@validations' do
      let(:method_name) { :foo }
      let(:contents) { {} }
      let(:error_msg) { 'foo has already been registered' }
      before(:each) do
        @validations = Lackeys::Registry.instance_variable_get(:@validations)
        Lackeys::Registry.instance_variable_set(:@validations, contents)
        param.add_validation method_name
      end

      after(:each) do
        Lackeys::Registry.instance_variable_set(:@validations, @validations)
      end

      it 'adds the method' do
        Lackeys::Registry.add(param)
        mthods = Lackeys::Registry.instance_variable_get(:@validations)
        expect(mthods[method_name]).to eql(observers: [Integer])
      end

      context 'an existing validation has already been registered' do
        let(:contents) { { foo: { observers: [Integer] } } }

        it { expect { Lackeys::Registry.add(param) }.to raise_error error_msg }
      end
    end

    context '@callbacks' do
      let(:method_name) { :foo }
      let(:callback_type) { :before_save }
      let(:contents) { { before_save: {} } }
      let(:error_msg) { 'foo has already been registered' }

      before(:each) do
        @callbacks = Lackeys::Registry.instance_variable_get(:@callbacks)
        Lackeys::Registry.instance_variable_set(:@callbacks, contents)
        param.add_callback :before_save, method_name
      end

      after(:each) do
        Lackeys::Registry.instance_variable_set(:@callbacks, @callbacks)
      end

      it 'adds the method' do
        Lackeys::Registry.add(param)
        mthods = Lackeys::Registry.instance_variable_get(:@callbacks)
        expect(mthods[callback_type][method_name]).to eql(observers: [Integer])
      end

      context 'an existing callback method has already been registered' do
        let(:contents) { { before_save: { foo: { observers: [Integer] } } } }

        it { expect { Lackeys::Registry.add(param) }.to raise_error error_msg }
      end
    end
  end
end
