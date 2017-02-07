# SwiftPlate 💾

Create projects from templates. It may be for app development, frameworks, ios apps and android apps. This is just an utility CLI which helps you
- fetch a template
- replace strings in filenames and inside files

Here's a template we're working on

- [hfossli/replicate-ios-app](https://github.com/hfossli/replicate-ios-app)

## Installation

### Download, compile and install
```
cd ~/Downloads && curl -L https://github.com/hfossli/SwiftPlate/archive/master.zip | tar zx && cd SwiftPlate-master && make
```

Then you'll be able to run `swiftplate` from any folder. E.g.
```
swiftplate --template hfossli/replicate-ios-app
```

### Manually

You can either

- Run `./main.swift` in your terminal.

or

- Run `make` in your terminal to install SwiftPlate.
- Run `swiftplate` in your terminal.

or

- Open `SwiftPlate.xcodeproj`.
- Run the project, and use Xcode’s console to provide input.

or

- Open `SwiftPlate.xcodeproj`.
- Archive the project.
- Move the built binary to `/usr/local/bin`.
- Run `swiftplate` in your terminal.

## Example

1. Install SwiftPlate and paste this into terminal
```
swiftplate --template hfossli/swiftplate-ios-app --destination Foo
```
2. Answer the questions popping up
3. Open folder `Foo` and you'll see a project ready for development

## Options

You may use the guide to input information or you may pass options as arguments on launch. The SwiftPlate program only has 3 options, but a template may ask for more.

### SwiftPlate options

| Name        | Description                                 | Long parameter  |
|:------------|:--------------------------------------------|:----------------|
| Destination | Where the generated project should be saved | `--destination` |
| Template    | The location of your template               | `--template`    |
| Force       | Don't use the interactive mode              | `--force`       |

### Each template will have its own options

E.g. [hfossli/swiftplate-ios-app](https://github.com/hfossli/swiftplate-ios-app) can be used like so
```
main.swift --template hfossli/swiftplate-ios-app --destination FooBar --project-name "XYZFooBar" --company-name "The lot"
```

## Similar concepts

- [Toughtbot's liftoff](https://github.com/thoughtbot/liftoff)
- [SwiftPlate](https://github.com/JohnSundell/SwiftPlate)

Why don't you use [Toughtbot's liftoff](https://github.com/thoughtbot/liftoff) or [SwiftPlate](https://github.com/JohnSundell/SwiftPlate)? Simply because they're geared towards one specific setup.

## Creating templates

### SwiftPlate.json

In the root directory of your template project add a file named `swiftplate.json` with some information about which strings you want replaced. Here's an example:
```
{
  "replace": [
    {
      "find": "S-PROJECT-NAME",
      "description": "What's the name of your project?",
      "suggestion": "folder.name"
    },
    {
      "find": "S-AUTHOR-NAME",
      "description": "What's your name?",
      "suggestion": "git.user.name"
    },
    {
      "find": "S-AUTHOR-EMAIL",
      "description": "What's your email address?",
      "suggestion": "git.user.email"
    },
    {
      "find": "S-COMPANY-NAME",
      "description": "What's your company name?"
    },
    {
      "find": "S-COMPANY-IDENTIFIER",
      "description": "What's your company identifier? E.g. \"no.agens\""
    }
  ]
}
```

Until we reach 1.0 this format is subject to change. After that it will only be additive features.

#### Replace

The replace dictionary may concist of following keys

##### find (required string)
Used to determine which strings to replace.

##### name (optional string)
If this is omitted we will derive the name from the "find" attribute. Used as argument name for CLI. E.g. setting `find` to `S-COMPANY-NAME` will make `--company-name` available as a CLI argument.

##### description (required string)
Text used by CLI to ask user for input.

##### optional (optional bool)
Is this optional or required?

##### suggestion (optional string)
As you may see in the "suggestion" attribute in json you can specify suggestions which are dynamic. We support

- git.user.email
- git.user.name
- folder.name
- date.year

##### hidden (optional bool)
Used in combination with `suggestion` to inject dynamic fields like `date.year` in copyright texts.

### Best practices

1. For strings you want replaced prefix them with `S-` e.g. `S-AUTHOR-NAME`
2. Only use `-` or characthers `A-Z`. E.g. don't name your project file `<%PROJECT%>.xcodeproj` as xcode will have a hard time dealing with that while developing your template. Instead name your project `S-PROJECT-NAME.xcodeproj`.


## Questions or feedback?

Feel free to [open an issue](https://github.com/JohnSundell/SwiftPlate/issues/new), or find me [@johnsundell on Twitter](https://twitter.com/johnsundell).
