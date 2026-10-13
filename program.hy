public class Program {
    public static int Main(string[] args) {
        System.Console.WriteLine("Australis command shell (early preview)");
        System.Console.WriteLine("Type help or exit.");
        bool running = true;
        while (running) {
            System.Console.Write("australis> ");
            string line = System.Console.ReadLine();
            if (line == "exit") {
                running = false;
            } else if (line == "help") {
                System.Console.WriteLine("help  Show this message");
                System.Console.WriteLine("exit  Return to KMon");
            } else if (line == "") {
                // Keep the prompt after an empty line.
            } else {
                System.Console.WriteLine("Command launch is not available yet.");
            }
        }
        return 0;
    }
}
