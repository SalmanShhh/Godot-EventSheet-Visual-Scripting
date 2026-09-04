# Fixture pack builder that publishes nothing at all: a file in the builders folder with a build()
# that ships no pack. It must not count, and it must not take the walk down either.
@tool


static func build() -> bool:
	return true
