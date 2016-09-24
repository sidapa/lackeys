
[![Build Status](https://circleci.com/gh/sidapa/lackeys.svg?style=shield&circle-token=:circle-token)](https://circleci.com/gh/sidapa/lackeys)

# Lackeys

Lackeys is a full featured implementation of the observer pattern. This gem allows a objects to provide a host model with new functionality without changing anything on the host object.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'lackeys'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install lackeys

## Usage

TODO: Write usage instructions here

### Transactional Events

When method is registered with `multi: true` option, an additional option *transaction* is available to the user.

specifying `transaction: true` in the method declaration will ensure that all changes to states happen at the same time. The the following sample code:

```ruby
# Service that sets the @parents' attribute
class GenericAttributeHandler < Lackeys::ServiceBase
  # Add registration code here

  def attr_setter(new_value)
    @parent.attribute = new_value
  end
end

# Logger Service
class LoggerService < Lackeys::ServiceBase
  # Add registration code here

  def attr_log(new_value)
    Logger.info "#{@parent.attribute} -> #{new_value}"
  end
end
```

Since both services are get called sequentially in `multi: true` methods, it is possible, since they are referencing the same parent object, that the attribute value will have changed before the next observer method is invoked.

To prevent this from happening, `transaction: true` will also be enabled.

To use transactional events, subscribed Services must do the following:

- Store changes as internal states.
- Provide a `commit` method which makes the final changes based on internal states.

The above services, when converted to transactional events, will be changed to:

```ruby
# Service that sets the @parents' attribute
class GenericAttributeHandler < Lackeys::ServiceBase
  # Add registration code here

  def attr_setter(new_value)
    @new_value= new_value
  end

  def commit
    @parent.attribute = @new_value
  end
end

# Logger Service
class LoggerService < Lackeys::ServiceBase
  # Add registration code here

  def attr_log(new_value)
    @old_value = @parent.attribute
    @new_value = new_value
  end

  def commit
    Logger.info "#{@parent.attribute} -> #{new_value}"
  end
end
```

## Contributing

1. Fork it ( https://github.com/[my-github-username]/lackeys/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
