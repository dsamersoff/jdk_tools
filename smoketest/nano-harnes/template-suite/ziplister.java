import java.io.FileInputStream;
import java.io.IOException;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;

import java.io.BufferedReader;
import java.io.FileNotFoundException;
import java.util.zip.GZIPInputStream;
import java.io.InputStreamReader;

public class ziplister {

    static int listZip(String zipFilePath) {
        try (ZipInputStream zipInputStream = new ZipInputStream(new FileInputStream(zipFilePath))) {
            ZipEntry entry;

            while ((entry = zipInputStream.getNextEntry()) != null) {
                System.out.println("File: " + entry.getName());
            }

            return 0;
        } catch (IOException e) {
            e.printStackTrace();
            return 1;
        }
    }

    static int readGZ(String gzFilePath) {
        try {
                BufferedReader in = new BufferedReader(new InputStreamReader(
                    new GZIPInputStream(new FileInputStream(gzFilePath))));

                String content;
                while ((content = in.readLine()) != null) {
                    System.out.println(content);
                }
            return 0;
        } catch (IOException e) {
            e.printStackTrace();
            return -1;
        }
    }


    public static void main(String[] args) {
        if (args[0].equals("-help")) {
            System.out.println("Usage: ziplister zipfile");
            System.exit(0);
        }
        String filePath = args[0];
        int retcode = -1;
        if (filePath.endsWith(".gz")) {
           retcode = readGZ(filePath);
        }
        else {
           retcode = listZip(filePath);
        }
        System.exit(retcode);
    }
}

