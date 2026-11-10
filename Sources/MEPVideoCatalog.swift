import Foundation

protocol MEPWeeklyVideoProviding {
    func videos(for year: Int, weekNumber: Int) -> [GeneratedLearningPlan.SuggestedVideo]
}

/// Supplies the curated videos independently of the curriculum-to-plan conversion rules.
struct MEPVideoCatalog: MEPWeeklyVideoProviding {
    private let weeksPerCourse = 4

    func videos(for year: Int, weekNumber: Int) -> [GeneratedLearningPlan.SuggestedVideo] {
        let videoLibrary: [GeneratedLearningPlan.SuggestedVideo]
        switch year {
        case 1:
            videoLibrary = [
                video("Adding 1 vs. adding 10", "mKsKU0BAiRM", topic: "place value and adding tens"),
                video("Recognizing shapes", "10dTx1Zy_4w", topic: "naming and describing shapes"),
                video("Introduction to place value", "wx2gI8iwMCA", topic: "ones and tens"),
                video("Counting in pictures", "leDYnoNSvD4", topic: "counting pictured objects"),
                video("Counting in order", "PEeUTQ0Gri8", topic: "counting objects in sequence"),
                video("Adding 8 + 7", "AK0NZITv5Ns", topic: "making ten to add"),
                video("Skip counting by 5", "UwWn84u6i8s", topic: "skip counting by fives"),
                video("Number grid", "9XZypM2Z3Ro", topic: "number patterns through 100"),
                video("Counting with small numbers", "y2-uaPiyoxc", topic: "counting small groups"),
                video("Halves and fourths", "0lSTXtwPuOU", topic: "sharing shapes into equal parts"),
                video("Adding 7 + 6", "ZgzpTx-s9Zo", topic: "making ten to add"),
                video("Comparison word problems", "osIFa9zcI-w", topic: "comparing quantities in story problems")
            ]
        case 2:
            videoLibrary = [
                video("Adding 2-digit numbers without regrouping", "EV38zfiY6Vs", topic: "two-digit addition"),
                video("Addition and subtraction", "MwerJr42bQw", topic: "addition and subtraction stories"),
                video("Subtracting a 1-digit number with regrouping", "zvetEuVJ0bE", topic: "regrouping when subtracting"),
                video("Subtracting two-digit numbers without regrouping", "RzEFGpe0rv4", topic: "subtracting tens and ones"),
                video("Subtracting 3-digit numbers without regrouping", "i8r7ZTUqB9w", topic: "hundreds, tens, and ones"),
                video("Subtracting with regrouping", "Ds226Vh7epg", topic: "subtracting by regrouping tens and ones"),
                video("Comparing inches and centimeters", "CSWPyCaIMsQ", topic: "measuring length in different units", channel: "YouTube"),
                video("Measuring with a broken ruler", "A6owsT9NBpQ", topic: "measuring length from a shifted starting point", channel: "YouTube"),
                video("Telling time to the nearest five minutes", "h6RNkQ7lU8Y", topic: "reading an analog clock", channel: "LearnZillion"),
                video("Line plot song", "VS1fLbeuRkU", topic: "organizing measurement data on a line plot", channel: "YouTube"),
                video("Creating a line plot", "xa2ICYALJ9Y", topic: "representing data on a line plot", channel: "YouTube"),
                video("Picture graphs and bar graphs", "_H0M0XzjmIA", topic: "reading picture and bar graphs", channel: "YouTube")
            ]
        case 3:
            videoLibrary = [
                video("Practice finding patterns in numbers", "l-6uEtTBH7g", topic: "number patterns"),
                video("Properties and patterns for multiplication", "um2nlNVM_YM", topic: "multiplication patterns"),
                video("Finding perimeter when a side length is missing", "tmt5fXhU7Rs", topic: "perimeter and missing side lengths"),
                video("Intuition for grams", "zqduFg0s5Q4", topic: "measuring mass"),
                video("Representing one-step word problems", "ZVXimuY5FkE", topic: "translating a story into operations"),
                video("Counting U.S. dollars and coins", "2E9ghvxEFTw", topic: "counting money and making totals"),
                video("Patterns in a multiplication table", "3y4N_5_R8ME", topic: "finding patterns in multiplication facts"),
                video("Representing word problems", "M7nJnjh0XKI", topic: "modeling a word problem"),
                video("Solving division word problems", "l6sqk4RFHMc", topic: "division in equal-group stories"),
                video("Solving another division word problem", "RiP6EgKEZNU", topic: "choosing division for a story problem"),
                video("Solving multiplication word problems", "fs_r0vViUb8", topic: "multiplication in equal-group stories"),
                video("Picture and bar graphs", "g-Xjkiiz1qw", topic: "representing and reading data")
            ]
        case 4:
            videoLibrary = [
                video("Categorizing geometric shapes", "PiQxA9O7Rd8", topic: "classifying shapes and angles"),
                video("Input & output tables: identifying the rule", "Y9oW96dhzg0", topic: "number patterns and rules"),
                video("Metric system: units of distance", "I3kQJvR7ZIg", topic: "metric distance units"),
                video("Multiplying 1-digit numbers by 10, 100, and 1000", "SG4gX-VGzog", topic: "place value and multiplication"),
                video("Measuring angles with a circular protractor", "Ttji2_wBSEo", topic: "measuring angles"),
                video("Calculating profit with multiplication", "iCA78yjz_HY", topic: "multiplication in a real-world problem"),
                video("Multiplying two-digit numbers", "DaQlieZH1kk", topic: "multiplying two-digit numbers"),
                video("Multiplying two-digit numbers with the distributive property", "3JmnxR8nEi8", topic: "breaking multiplication into place-value parts"),
                video("Common fractions and decimals", "lh2mp0aqSh8", topic: "connecting common fractions and decimals"),
                video("Comparing fractions visually with a bar", "ory05j2jgBM", topic: "comparing fractions with visual models"),
                video("Comparing with multiplication", "KFzcwWTEDDI", topic: "comparing quantities using multiplication"),
                video("Comparing with multiplication: another example", "hjnyAogBdBk", topic: "solving a multiplication comparison")
            ]
        case 5:
            videoLibrary = [
                video("Number patterns: visualizing sequence relationships", "mqsIJucBn6c", topic: "number patterns"),
                video("Common Fractions and Decimals", "sSHo2OwSOIM", topic: "fractions and decimals"),
                video("Volume through decomposition", "feNWZEln6Nc", topic: "volume and measurement"),
                video("Units of measurement word problem: volume", "PdHSs5_kx24", topic: "volume word problems"),
                video("Multiplying fractions: visualizing", "hr_mTd-oJ-M", topic: "visual models for fraction multiplication"),
                video("Dividing decimals with hundredths", "Hrjr5f5pZ84", topic: "decimal division"),
                video("Decimal multiplication with grids", "3Phgu3ExLmY", topic: "area models for multiplying decimals"),
                video("Creating volume expressions", "NDPTBKbWmy8", topic: "writing expressions for prism volume"),
                video("Using fractions as division to create mixed numbers", "g8yk6zQDAek", topic: "fractions as division"),
                video("Coordinate plane: graphing points", "4vNloi-zNjU", topic: "plotting points on a coordinate plane"),
                video("Volume in unit cubes by decomposing shape", "gm87omItizk", topic: "finding volume by splitting a solid into parts"),
                video("Adding decimals with thousandths", "_ayXtD83wBA", topic: "adding decimals by place value")
            ]
        default:
            videoLibrary = [
                video("Introduction to ratios", "bIKmw0aTmYc", topic: "ratios and comparing quantities"),
                video("Introduction to rates", "qGTYSAeLTOE", topic: "rates and unit comparisons"),
                video("Finding area by breaking up the shape", "loAA3TCNAvU", topic: "area and geometry"),
                video("How to interpret a histogram", "c02vjunQsJM", topic: "data and graphs"),
                video("Comparing negatives with variables", "kQkeayQke8A", topic: "comparing negative values on a number line"),
                video("Number opposites practice", "vRa6XxykfbY", topic: "opposites on a number line"),
                video("Sorting absolute values on a number line", "MFoXK57sw9k", topic: "ordering absolute values"),
                video("Comparing absolute values on a number line", "29P6bar7nHc", topic: "comparing absolute values"),
                video("Negative numbers in real life: temperature and elevation", "qKOojMSCkTA", topic: "interpreting negative numbers in context", channel: "YouTube"),
                video("Adding and subtracting negative numbers", "DBSviXhkubg", topic: "integer addition and subtraction", channel: "YouTube"),
                video("Comparing negative and positive numbers", "9-f9eAiEF7g", topic: "ordering positive and negative values", channel: "YouTube"),
                video("Thinking about shapes of data distributions", "2oJldeE4JcU", topic: "describing data distributions")
            ]
        }

        let videosPerWeek = 3
        precondition(videoLibrary.count == weeksPerCourse * videosPerWeek)
        precondition(Set(videoLibrary.map(\.url)).count == videoLibrary.count)
        guard (1...weeksPerCourse).contains(weekNumber) else { return [] }
        let startIndex = (weekNumber - 1) * videosPerWeek
        return Array(videoLibrary[startIndex..<(startIndex + videosPerWeek)])
    }

    private func video(
        _ title: String,
        _ videoID: String,
        topic: String,
        channel: String = "Khan Academy"
    ) -> GeneratedLearningPlan.SuggestedVideo {
        GeneratedLearningPlan.SuggestedVideo(
            title: title,
            channel: channel,
            url: "https://www.youtube.com/watch?v=\(videoID)",
            reason: "A grade-appropriate video about \(topic), one of this week's practice topics."
        )
    }

}
