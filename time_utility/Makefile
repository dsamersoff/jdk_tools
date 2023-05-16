CXX = g++
CXXFLAGS = -Wall -Werror -pedantic -std=c++14
LDFLAGS = -lrt

TARGET = time_ex
SRC = time_ex.cpp

all: $(TARGET)

$(TARGET): $(SRC)
	$(CXX) $(CXXFLAGS) $(LDFLAGS) -o $@ $<

clean:
	rm -f $(TARGET)
