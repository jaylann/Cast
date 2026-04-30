// What this shows: every shipped Cast property wrapper exercised in one struct,
// so you can copy-paste the syntax for each one. @Validator is covered by the
// ValidatorAndExcluding example, per the issue conventions.

import Cast
import Collections
import Foundation
import JSONSchema

@Castable
struct Recipe {
    @MaxLength(80) var title: String = ""
    @MinLength(10) @MaxLength(500) var summary: String = ""
    @CastRange(1 ... 5) var difficulty: Int = 0
    @Precision(1) var rating: Double = 0
    @MinCount(1) @MaxCount(8) var ingredients: [String] = []
    @Count(3) var steps: [String] = []
    @OneOf(["breakfast", "lunch", "dinner"]) var meal: String = ""
    @Pattern("^[A-Z][a-z]+$") var cuisine: String = ""
    @Description("Dietary style of the dish")
    @Examples("vegan", "keto") var diet: String = ""
    @Nullable var notes: String?
    @DefaultValue(4) var servings: Int = 0
}

@main
enum PropertyWrappersTour {
    static func main() async throws {
        let model = try await CastModel.load("mlx-community/Llama-3.2-3B-Instruct-4bit")
        let recipe: Recipe = try await model.cast(
            "Generate a quick weeknight stir-fry recipe with 4 servings."
        )
        print(recipe)
    }
}

// Sample output (illustrative):
// Recipe(title: "Quick Beef Stir-Fry", summary: "A fast weeknight dinner...",
//        difficulty: 2, rating: 4.5, ingredients: ["beef", "soy sauce", ...],
//        steps: ["Marinate", "Sear", "Toss"], meal: "dinner",
//        cuisine: "Asian", diet: "omnivore", notes: nil, servings: 4)
